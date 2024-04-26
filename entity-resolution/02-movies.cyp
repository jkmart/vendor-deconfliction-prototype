// Constraints
CREATE CONSTRAINT genre_name IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE;
CREATE CONSTRAINT movie_id IF NOT EXISTS FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;
// Index
CREATE INDEX movie_title IF NOT EXISTS FOR (m:Movie) ON (m.title);

//Load Data
LOAD CSV WITH HEADERS FROM
"https://raw.githubusercontent.com/neo4j-graph-examples/entity_resolution/main/data/csv/Movies.csv" AS row

// conditionally create movie and set properties on first creation
MERGE ( m:Movie { movieId: toInteger(row.movieId) })
ON CREATE SET
m.title = row.name,
m.year = toInteger(row.year)

WITH m, row
// create Genre if not exists
MERGE (g:Genre { name: row.genre } )
// create relationship if not exists
MERGE (m)-[:HAS]->(g)
RETURN m, g;