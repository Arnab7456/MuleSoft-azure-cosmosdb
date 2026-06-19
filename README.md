# Azure Cosmos DB Integration with Mule 4

This Mule 4 application demonstrates how to integrate with **Azure Cosmos DB** (SQL API) using the official Azure Cosmos DB Connector. It provides REST endpoints to create, retrieve, and list documents within a specific database (`StoreDatabase`) and collection/container (`Products`).

---

## Features

* **Create Document**: Inserts a new JSON document into a partition-managed Azure Cosmos DB container.
* **Get Document by ID**: Retrieves a specific document from a partition using its unique ID and partition key.
* **List Documents**: Fetches all documents available within the specified container.
* **Global Error Handling**: References a centralized error handler (`globalError_Handler`) across all flows for consistent exception management.

---

## Prerequisites

Before running the application, ensure you have the following:

* **Anypoint Studio 7.x** or higher
* **Mule Runtime 4.x** or higher
* An active **Azure Cosmos DB Account** (SQL API)
* A Database named `StoreDatabase` and a Container named `Products` configured in your Cosmos DB instance.

---

## Configuration

The application externalizes its environment configuration. Update or create your `config.properties` file in `src/main/resources/` with the following keys:

```properties
# HTTP Listener Configuration
http.host=0.0.0.0
http.port=8081

# Azure Cosmos DB Connection Details
cosmos.baseUri=https://<your-cosmos-db-account-name>.documents.azure.com:443/
cosmos.key=<your-cosmos-db-primary-or-secondary-master-key>
cosmos.version=2018-12-31

```

---

## API Endpoints & Usage

### 1. Create Document

Inserts a new JSON payload into the Azure Cosmos DB container.

* **HTTP Method**: `POST`
* **Path**: `/create/partition/{partitionKey}`
* **Headers**: `Content-Type: application/json`
* **Body**: The JSON object you wish to store.
* **Example Request**:
```bash
curl -X POST http://localhost:8081/create/partition/Electronics \
  -H "Content-Type: application/json" \
  -d '{"id": "prod_101", "name": "Wireless Mouse", "category": "Electronics", "price": 29.99}'

```



### 2. Get Document

Retrieves a single document using its distinct document ID and associated partition key.

* **HTTP Method**: `GET`
* **Path**: `/get-document/partition/{partitionKey}/doc/{docId}`
* **Example Request**:
```bash
curl -X GET http://localhost:8081/get-document/partition/Electronics/doc/prod_101

```



### 3. List Documents

Lists documents present inside the designated `Products` collection.

* **HTTP Method**: `GET`
* **Path**: `/list`
* **Example Request**:
```bash
curl -X GET http://localhost:8081/list

```



---

## Project Structure & Flow Overview

* **`az-cosmosFlow`**: Listens on `/get-document/...`, invokes the `get-document` operation by mapping the `x-ms-documentdb-partitionkey` header dynamically, transforms the response to JSON, and logs the payload.
* **`az-cosmosFlow1`**: Listens on `/list`, wraps the `list-documents` operation inside a `try` scope for localized error isolation, and outputs the list as a JSON array.
* **`az-cosmosFlow2`**: Listens on `/create/...`, processes incoming JSON body text, executes the `create-document` operation using the dynamic partition path variable, and returns the metadata of the created item.
