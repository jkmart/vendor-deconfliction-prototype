// https://github.com/neo4j-graph-examples/enitity_resolution

/// Watched Boss Baby
MATCH (u:User)-[w:WATCHED]->(m:Movie {title: "The Boss Baby: Family Business"})
RETURN u, w, m LIMIT 5


/// Watched in NY
MATCH (u:User {state: "New York"} )-[w:WATCHED]->(m)  RETURN u, w, m LIMIT 50


/// Trending in Texas
MATCH (u:User {state: "Texas"} )-[:WATCHED]->(m)-[:HAS]->(g:Genre)
// group by genre, order by frequency
RETURN g.name as genre, count(g) as freq
  ORDER BY freq DESC


/// Same / similar names
MATCH (a:User)
MATCH (b:User)
// not the same user
  WHERE a <> b

// users with full-names
WITH a, b, a.firstName + ' ' + a.lastName AS name1, b.firstName + ' ' + b.lastName AS name2

// compute different similiarities
WITH *,
  toInteger(apoc.text.sorensenDiceSimilarity(name1, name2) * 100) AS nameSimilarity,
  toInteger(apoc.text.sorensenDiceSimilarity(a.email, b.email) * 100) AS emailSimilarity,
  toInteger(apoc.text.sorensenDiceSimilarity(a.phone, b.phone) * 100) AS phoneSimilarity

// compute a total similarity score
WITH a, b, name1, name2, toInteger((nameSimilarity + emailSimilarity + phoneSimilarity)/3) as similarity

// filter
  WHERE similarity >= 90

RETURN name1, name2, a.email, b.email,  similarity

  ORDER BY similarity DESC


/// Shared Family
// shared IP address
MATCH (a:User)-->(ip:IpAddress)<--(b:User)
// same lastname and state
  WHERE a.lastName = b.lastName
  AND a.state = b.state AND a.country = b.country

// group by joint attributes, collect all member-names
WITH ip, a.country as country, a.state as state,
     a.lastName as familyName,
     collect(distinct b.firstName + ' '  + b.lastName) as members,
     count(distinct b) as memberCount

RETURN state, familyName, memberCount, members
  ORDER BY memberCount DESC


/// Link shared family to common node
// shared IP address
MATCH (a:User)-->(ip:IpAddress)<--(b:User)
// same lastname and state
  WHERE a.lastName = b.lastName
  AND a.state = b.state AND a.country = b.country

// group by joint attributes, collect all members
WITH ip, a.country as country, a.state as state,
     a.lastName as familyName,
     collect(distinct b) as familyMembers,
     count(distinct b) as totalMembers
WITH familyName, head(familyMembers) as first, tail(familyMembers) as rest
// not global family but within first member
MERGE (first)-[:BELONGS_TO]->(f:Family {name: familyName})
WITH f,rest

UNWIND rest as member

MERGE (member)-[r:BELONGS_TO]->(f)
RETURN count(*);


/// How many families created
MATCH (f:Family)<-[b:BELONGS_TO]-(u:User)

RETURN f, b, u LIMIT 200


/// Recommend based on family
MATCH (user:User {firstName: "Vilma", lastName: "De Mars"})
// other family members
MATCH (user)-[:BELONGS_TO]->(f)<-[:BELONGS_TO]-(otherMember)

// what have they watched and transitive via genre
MATCH (otherMember)-[:WATCHED]->(m1)-[:HAS]->(g:Genre)<-[:HAS]-(m2)

// aggregate by genre, sort by watch count
WITH g, count(*) as watched, m2
  ORDER BY watched DESC

// count totals per genre, top-5 watched per genre
WITH g, count(distinct m2) as totalMovies, collect(m2.title)[0..5] as movies

// return 5 per genre
RETURN g.name as genre, totalMovies, movies as topFiveMovies
  ORDER BY totalMovies DESC LIMIT 10


/// Node similarity for recommends
// In-memory graph
CALL gds.graph.project(
'similarityGraph',
// labels
['User', 'Movie'],
{
// relationships
  WATCHED: {
             type: 'WATCHED',
             properties: {
                     strength: {
                                 property: 'watchCount',
                                 defaultValue: 1
                               }
                   }
           }
}
);

// Simulate memory estimate
CALL gds.nodeSimilarity.write.estimate('similarityGraph', {
  writeRelationshipType: 'SIMILAR',
  writeProperty: 'score'
})
YIELD nodeCount, relationshipCount, bytesMin, bytesMax, requiredMemory

// Execute
CALL gds.nodeSimilarity.stream('similarityGraph')
// return ids and similarity
YIELD node1, node2, similarity
WITH * ORDER BY similarity DESC LIMIT 50
// fetch nodes by id
WITH gds.util.asNode(node1) AS person1, gds.util.asNode(node2) AS person2, similarity
RETURN
  person1.firstName + ' ' +  person1.lastName as p1,
  person2.firstName  + ' ' +   person2.lastName as p2, similarity;

// Get recommendations
MATCH (person1:User)
  WHERE person1.firstName = 'Paulie' AND person1.lastName = 'Imesson'

CALL gds.nodeSimilarity.stream('similarityGraph')
YIELD node1, node2, similarity
// limit to our user
  WHERE node1 = id(person1)

WITH person1, gds.util.asNode(node2) AS person2, similarity

// what did the other people watch
MATCH (person2)-[w:WATCHED]->(m)
// that our user hasn't seen
  WHERE NOT exists { (person1)-[:WATCHED]->(m) }

RETURN m.title as movie, SUM(w.watchCount) as watchCount
  ORDER BY watchCount DESC LIMIT 10