use std::sync::Arc;

use axum::{Json, Router};
use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::get;
use clap::{Args, Parser, Subcommand};
use neo4rs::*;
use serde::{Deserialize, Serialize};

#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    #[arg(short, short_alias = 'u', long, required = true)]
    user: String,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Args)]
struct RequestVendor {
    #[arg(short, short_alias = 'v', long)]
    pub vendor_name: Option<String>,
    #[arg(short, short_alias = 'p', long)]
    pub project_name: Option<String>,
}

#[derive(Args)]
struct AddProject {
    #[arg(short, short_alias = 'p', long)]
    pub project_name: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    AddProject(AddProject),
    RequestVendor(RequestVendor),
    Server,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let config = ConfigBuilder::default()
        .uri("127.0.0.1:7687")
        .user("neo4j")
        .password("password")
        .db("neo4j")
        .fetch_size(500)
        .max_connections(10)
        .build()
        .unwrap();
    let graph = Graph::connect(config).await.unwrap();

    let user = &cli.user;
    match &cli.command {
        Commands::AddProject(add) => add_project(graph.clone(), user, add).await,
        Commands::RequestVendor(request) => request_vendor(graph.clone(), user, request).await,
        Commands::Server => server(graph.clone()).await
    };
}

struct AppState {
    graph: Graph
}

async fn server(graph: Graph) {

    let shared_state = Arc::new(AppState { graph });
    // build our application with a route
    let app = Router::new()
        // `GET /` goes to `root`
        .route("/", get(root))
        // `POST /users` goes to `create_user`
        .route("/projects", get(projects))
        .with_state(shared_state);

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3001").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

// basic handler that responds with a static string
async fn root() -> &'static str {
    "Vendor Deconfliction Engine Prototype"
}

async fn projects(State(state): State<Arc<AppState>>) -> (StatusCode, Json<Projects>) {

    let mut project_result: Vec<Project> = vec![];

    let mut stream_one = state.graph.execute(
        query("MATCH (p:Project) RETURN p")
    ).await.unwrap();
    loop {
        if let Some(row) = stream_one.next().await.unwrap() {
            let project = row.to::<Project>().unwrap();
            project_result.push(project);
        } else {
            break
        }
    }

    let projects = Projects { projects: project_result};

    // this will be converted into a JSON response
    (StatusCode::OK, Json(projects))
}

#[derive(Deserialize, Serialize)]
struct Project {
    id: String,
    name: String,
}

#[derive(Serialize)]
struct Projects {
    projects: Vec<Project>,
}

async fn add_project(graph: Graph, user: &str, add_project: &AddProject) {
    let project_name = match &add_project.project_name {
        None => {
            eprintln!("No project name provided");
            return;
        }
        Some(name) => name.to_owned(),
    };
    // Generate new id
    let id = uuid::Uuid::new_v4().to_string();
    // Start a new transaction
    let mut txn = graph.start_txn().await.unwrap();
    let mut project_result = txn
        .execute(
            query("MATCH (u:User) WHERE u.name = $username CREATE (p:Project {id: $id, name: $project})<-[:MANAGES]-(u) RETURN p")
                .param("id", id.as_str())
                .param("project", project_name.as_str())
                .param("username", user),
        )
        .await
        .unwrap();
    let project_node: Node = match project_result.next(txn.handle()).await {
        Ok(row) => {
            if let Some(row) = row {
                row.get("p").unwrap()
            } else {
                eprintln!("Failed to create project");
                txn.rollback().await.unwrap();
                return;
            }
        }
        Err(err) => {
            eprintln!("Could not create project: {}", err);
            txn.rollback().await.unwrap();
            return;
        }
    };
    assert_eq!(project_node.get::<String>("id").unwrap(), id.clone());
    println!(
        "Successfully created new project {} with id {}",
        project_name, id
    );
    txn.commit().await.unwrap();
}

async fn request_vendor(graph: Graph, username: &String, request_vendor: &RequestVendor) {
    let vendor_name = match &request_vendor.vendor_name {
        None => {
            eprintln!("No vendor name provided");
            return;
        }
        Some(name) => name.to_owned(),
    };
    let project_name = match &request_vendor.project_name {
        None => {
            eprintln!("No project name provided");
            return;
        }
        Some(name) => name.to_owned(),
    };

    let mut result = match graph.execute(
        query("MATCH (:Vendor {name: $vendor})<-[r:USES_VENDOR]-(:Project) WHERE r.end IS NULL RETURN r")
            .param("vendor", vendor_name.clone())
    ).await {
        Ok(x) => x,
        Err(err) => {
            eprintln!("Unable to execute query: {}", err);
            return;
        }
    };

    let result = match result.next().await {
        Ok(x) => x,
        Err(_) => {
            eprintln!("Could not reach database!");
            return;
        }
    };
    let vendor_conflict: bool = match result {
        None => {
            println!("No vendor conflict found");
            false
        }
        Some(row) => {
            let relation: Relation = row.get("r").unwrap();
            // Unnecessary assertions
            assert!(relation.id() > -1);
            assert!(relation.start_node_id() > -1);
            assert!(relation.end_node_id() > -1);
            assert_eq!(relation.typ(), "USES_VENDOR");
            assert!(relation.keys().contains(&"type"));
            let vendor_type = relation.get::<String>("type").unwrap();
            println!("Vendor is already being used for a project as a {}! Please reach out to an admin to resolve.", vendor_type);
            true
        }
    };

    if !vendor_conflict {
        // Make sure this is the managing user for the project
        let mut result = match graph
            .execute(
                query("MATCH (p:Project)<-[:MANAGES]-(u:User) WHERE p.name = $project_name RETURN u")
                    .param("project_name", project_name.clone()),
            )
            .await
        {
            Ok(x) => x,
            Err(err) => {
                eprintln!("Unable to execute query: {}", err);
                return;
            }
        };

        if let Some(user_result) = match result.next().await {
            Ok(x) => x,
            Err(_) => {
                eprintln!("Could not reach database!");
                return;
            }
        } {
            let user_node: Node = user_result.get("u").unwrap();
            // Pseudo permissions check
            if !user_node
                .get::<String>("name")
                .unwrap()
                .eq_ignore_ascii_case(username)
            {
                eprintln!(
                    "User {} is not the managing user of project {}! Cannot request vendor.",
                    username, project_name
                );
                return;
            }
            // Add this vendor to the project
            match graph.run(
                query("MATCH (v:Vendor) MATCH (p:Project) WHERE v.name = $vendor AND p.name = $project_name CREATE (v)<-[:USES_VENDOR {type: 'prime', start: date()}]-(p)")
                    .param("vendor", vendor_name.clone())
                    .param("project_name", project_name.clone())
            ).await {
                Ok(_) => {
                    println!("Added vendor {} to project {}", vendor_name, project_name)
                },
                Err(err) => {
                    eprintln!("Unable to execute query: {}", err);
                }
            };
        }
    } else {
        // Otherwise, we know there's a conflict
        // Notify the user managing the project
        tokio::spawn(async move { notify_managing_user(graph, vendor_name).await })
            .await
            .expect("Unable to send user notification of conflict");
    }
}

async fn notify_managing_user(graph: Graph, vendor_name: String) {
    let mut result = graph.execute(
        query("MATCH (v:Vendor)<-[r:USES_VENDOR]-(p:Project)<-[:MANAGES]-(u:User) WHERE v.name = $vendor AND r.end IS NULL RETURN p, u, v")
            .param("vendor", vendor_name)
    ).await.unwrap();

    let result = match result.next().await {
        Ok(x) => x,
        Err(_) => {
            eprintln!("Could not reach database!");
            return;
        }
    };

    match result {
        None => todo!("There should be a matching user"),
        Some(user_row) => {
            let user: Node = user_row.get("u").unwrap();
            let u_keys = user.keys();
            assert!(u_keys.contains(&"name"));

            let vendor: Node = user_row.get("v").unwrap();
            let v_keys = vendor.keys();
            assert!(v_keys.contains(&"name"));

            let project: Node = user_row.get("p").unwrap();
            let p_keys = project.keys();
            assert!(p_keys.contains(&"name"));
            println!(
                "DEBUG :: Secretly notifying {} managing user ({}) of vendor conflict for {}",
                project.get::<String>("name").unwrap(),
                user.get::<String>("name").unwrap(),
                vendor.get::<String>("name").unwrap()
            );
        }
    }
}
