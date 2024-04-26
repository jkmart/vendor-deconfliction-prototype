// Constraints

CREATE CONSTRAINT user_id IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE;
CREATE CONSTRAINT ip_address IF NOT EXISTS FOR (i:IpAddress) REQUIRE i.address IS UNIQUE;

// indexes
CREATE INDEX user_state IF NOT EXISTS FOR (u:User) ON (u.state);
CREATE INDEX user_firstName IF NOT EXISTS FOR (u:User) ON (u.firstName);
CREATE INDEX user_lastName IF NOT EXISTS FOR (u:User) ON (u.firstName);

// Data load
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/entity_resolution/main/data/csv/Users.csv" AS row

// Conditionally create User, set properties on first create
MERGE (u:User { userId: toInteger(row.userId) })
ON CREATE SET
u.firstName= row.firstName,
u.lastName= row.lastName,
u.gender= row.gender,
u.email= row.email,
u.phone= row.phone,
u.state= row.state,
u.country= row.country

WITH u, row
// create IpAddress if not exists
MERGE (ip:IpAddress { address: row.ipAddress })
// create unique relationship
MERGE (u)-[:USES]->(ip);