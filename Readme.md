
# Magento Docker Environment

This project provides a Docker-based setup for Magento, enabling you to quickly install a new Magento instance or use an existing Magento repository. The configuration includes essential services like Nginx, MariaDB, Varnish, PHP, Redis, Opensearch, Blackfire and N98 allowing for a full-featured local development environment.

## Features

- **Dockerized Environment**: Provides isolated containers for Magento services.
- **Nginx and Varnish**: Configured for high-performance caching.
- **MariaDB**: The database service for Magento.
- **SSL Support**: Included SSL configuration for secure HTTPS connections.
- **Customizable PHP Configuration**: Easily modify PHP settings.
- **N98**: Installed on the PHP service so you can speed up your development.
- **Redis and Opensearch**: Automatically installed configured in new or existing Magento instances.
- **Blackfire**: Profile your Magento and take your development to the next level 
- **Mailcatcher**: For sending test emails inside your local environment 
- **Makefile for Commands**: Simplifies common operations like starting, stopping, and resetting services.

## Prerequisites

- Docker installed [See Details](https://docs.docker.com/desktop/)
- (Optional) GNU Make for using make commands
- PV installed - If you using ubuntu: 
    ```bash
    apt-get install pv
    ```
- Having an account in [Commerce Marketplace](https://commercemarketplace.adobe.com/) and having Consumer Key and Secret within "Access keys"

## Installation Options

### Option 1. Install a New Magento Instance

1. Copy `.env.sample` to `.env`:
   ```bash
   cp .env.sample .env
   ```

2. Update `.env` with your specific configuration details.

3. Trigger the generation of required files and settings:
   ```bash
   make
   ```

4. Start your Docker containers (on the first time you run, Nginx will exit):
   ```bash
   docker compose up -d
   ```

5. Run the setup command:
   ```bash
   make setup-new-magento
   ```
6. The Magento URL is set on the .env as MAGENTO_URL. Access the Magento installation in your browser at `http://{MAGENTO_URL}`.

### Option 2. Use an Existing Magento Repository

1. Copy `.env.sample` to `.env`:
   ```bash
   cp .env.sample .env
   ```

2. Update `.env` to match your environment settings and link the repository path.

3. Trigger the generation of required files and settings:
   ```bash
   make
   ```

4. Copy the .sql database dump into de ./db folder (create folder if it doesn't exist)

5. Make sure the .sql file has the exact same name as the variable DB_DUMP_NAME at your .env file

6. Start your Docker containers (on the first time you run, Nginx will exit):
   ```bash
   docker compose up -d
   ```

7. Run the initialization command:
   ```bash
   make setup-existing-magento
   ```

8. The Magento URL is set on the .env as MAGENTO_URL. Access the Magento installation in your browser at `http://{MAGENTO_URL}`.

> ⚠️ **Note**: Running the same Docker Compose setup in different folders could result in database conflicts or data overwrites. Ensure the database names, ports, and volumes are unique to avoid unintended overwrites.

## Available Make Commands

This project includes a `Makefile` with various commands to simplify working with Magento and Docker:

- **Setup Commands**:
  - `make setup-new-magento` - Install a fresh Magento instance.
  - `make setup-existing-magento` - Configure the environment for an existing Magento repository.
- **Magento Pre-configured Commands**:
  - `make deploy_full` - Launch magento deploy with composer update.
  - `make deploy` - Launch magento deploy without composer update.
  - `make front_static_deploy` - Launch deploy of static frontend files (pub/static/frontend/*).
  - `make admin_static_deploy` - Launch deploy of static adminhtml files (pub/static/adminhtml/*).
  - `make di_deploy` - Launch setup:di:compile for dependency injections.
  - `make db_deploy` - Launch setup:upgrade --heep-generated for database updates.
- **Docker Commands**:
  - `make up` - Start the Docker containers in the background.
  - `make down` - Stop and remove all containers.
  - `make restart` - Restart all services.

- **Database Commands**:
  - `make db-import` - Import a database dump in MariaDB (using the Magento DB set on the env file).
  - `make db-export` - Export the current database state to a file.
> ⚠️ **Note**: Using make db-import will overwrite all data on your current MariaDB database set in your env.

- **Utility Commands**:
  - `make clean` - Remove any unused data or stopped containers.
  - `make logs` - View logs from all running containers.

## Docker Commands

You can also use standard Docker Compose commands as needed:

- **Start the environment**:
  ```bash
  docker compose up -d
  ```

- **Stop the environment**:
  ```bash
  docker compose down
  ```

- **Restart specific services**:
  ```bash
  docker compose restart <service_name>
  ```

- **View logs for a service**:
  ```bash
  docker compose logs <service_name>
  ```

## Troubleshooting

- **Database Conflicts**: If running multiple instances of this setup, ensure the database names, ports, and data volumes are unique.
- **Container Restarts**: If services fail to start, try restarting with `make restart` or `docker-compose restart <service_name>`.
- **Permissions Issues**: Adjust file and folder permissions as needed to ensure the Magento service has access.
- **XDEBUG on PHP storm**: Add the server mapping for the folders.
