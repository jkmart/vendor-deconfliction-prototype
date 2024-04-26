// Fake Data

CREATE (kindly_admin:User {name: 'Kindly Admin'})
CREATE (user1:User {name: 'User1'})
CREATE (user2:User {name: 'User2'})
CREATE (user3:User {name: 'User3'})
// Permissions
CREATE (admin_permissions:Permission)
CREATE (user_permissions:Permission)
// Create permission relationships
CREATE (kindly_admin)-[:HAS_PERMISSIONS]->(admin_permissions)
CREATE (user1)-[:HAS_PERMISSIONS]->(user_permissions)
CREATE (user2)-[:HAS_PERMISSIONS]->(user_permissions)
// Key Personnel
CREATE (kerry:User {name: 'Kerry Martin'})
CREATE (joe:User {name: 'Joe Test'})
CREATE (schofield:User {name: 'John Schofield'})

// Vendors
CREATE (vendor1234:Vendor {name: 'Vendor1234'})
CREATE (acme:Vendor {name: 'ACME Corp'})
CREATE (iex:Vendor {name: 'Iron EagleX'})
CREATE (weyland:Vendor {name: 'Weyland-Yutani Corporation'})
CREATE (mompop:Vendor {name: "Mom And Pop Co"})
CREATE (wayne:Vendor {name: "Wayne Enterprises"})
CREATE (pollo:Vendor {name: "El Pollo Loco"})
// Create key personnel relationships
CREATE (kerry)-[:PART_OF {start: date('2021-01-04')}]->(iex)
CREATE (joe)-[:PART_OF {start: date('2023-06-30'), end: date('2024-01-01')}]->(vendor1234)
CREATE (joe)-[:PART_OF {start: date('2024-01-01')}]->(acme)
CREATE (schofield)-[:PART_OF {start: date('1876-07-14')}]->(acme)
// Projects
CREATE (projectx:Project {id: '1', name: 'Project X'})
CREATE (projecty:Project {id: '2', name: 'Project Y'})
CREATE (insanity:Project {id: '3', name: 'Project Insanity Incognito'})
CREATE (project2024:Project {id: '4', name: 'Project 2024'})
// Assign vendors to projects as primes and subs
CREATE (projectx)-[:USES_VENDOR {type: 'prime', start: date('2020-01-01')}]->(vendor1234)
CREATE (projectx)-[:USES_VENDOR {type: 'sub', start: date('2020-01-01'), end: date('2021-01-01')}]->(acme)
CREATE (projecty)-[:USES_VENDOR {type: 'prime', start: date('2022-06-20')}]->(iex)
CREATE (projecty)-[:USES_VENDOR {type: 'sub', start: date('2022-06-20')}]->(acme)
CREATE (insanity)-[:USES_VENDOR {type: 'prime', start: date('2020-05-06'), end: date('2021-05-06')}]->(weyland)
// User / Project Management
CREATE (user1)-[:MANAGES]->(projectx)
CREATE (user1)-[:MANAGES]->(insanity)
CREATE (user2)-[:MANAGES]->(projecty)
CREATE (user2)-[:MANAGES]->(project2024)


// Constraints
//CREATE CONSTRAINT project_id IF NOT EXISTS FOR (p:Project) REQUIRE p.id IS UNIQUE;
