LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/neo4j-graph-examples/entity_resolution/main/data/csv/WatchEvent.csv" AS row

// find user and movie
MATCH (u:User {userId: toInteger(row.userId)})
MATCH (m:Movie {movieId: toInteger(row.movieId)})

// create relationship if not exists
MERGE (u)-[w:WATCHED]->(m)
// always update watchCount
SET w.watchCount = toInteger(row.watchCount);