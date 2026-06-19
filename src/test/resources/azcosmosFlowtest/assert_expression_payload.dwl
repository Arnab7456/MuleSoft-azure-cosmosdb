%dw 2.0
import * from dw::test::Asserts
---
payload must equalTo({
  "id": "prod-10025",
  "name": "Ergonomic Office Chair",
  "category": "furniture",
  "stock": 18,
  "price": 299,
  "tags": [
    "office",
    "chair",
    "ergonomic"
  ],
  "_rid": "6Po9AJoKmjQDAAAAAAAAAA==",
  "_self": "dbs/6Po9AA==/colls/6Po9AJoKmjQ=/docs/6Po9AJoKmjQDAAAAAAAAAA==/",
  "_etag": "\"0000ad01-0000-2000-0000-6a2d9f5d0000\"",
  "_attachments": "attachments/",
  "_ts": 1781374813
})