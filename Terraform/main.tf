# Specify the required Terraform version
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.0.0"
}

# Specify the Docker provider
provider "docker" {
  host = "unix:///var/run/docker.sock"  # Use the Docker socket for macOS/Linux
}

# Step 2: Create Docker network for the services
resource "docker_network" "services_network" {
  name = "services_network"
}

# Step 3: Create Volumes for Persistent Data
resource "docker_volume" "jenkins_volume" {
  name = "jenkins_data"
}

resource "docker_volume" "grafana_volume" {
  name = "grafana_data"
}

resource "docker_volume" "prometheus_volume" {
  name = "prometheus_data"
}

# Step 4: Jenkins Container Setup
resource "docker_container" "jenkins" {
  image = "jenkins/jenkins:lts"
  name  = "jenkins"
  restart = "always"

  # Correct volume attachment using mount
  mounts {
    target = "/var/jenkins_home"
    source = docker_volume.jenkins_volume.name
    type   = "volume"
  }

  networks_advanced {
    name = docker_network.services_network.name
  }

  ports {
    internal = 8080
    external = 8080
  }

  ports {
    internal = 50000
    external = 50000
  }
}

# Step 5: Grafana Container Setup
resource "docker_container" "grafana" {
  image = "grafana/grafana:latest"
  name  = "grafana"
  restart = "always"

  # Correct volume attachment using mount
  mounts {
    target = "/var/lib/grafana"
    source = docker_volume.grafana_volume.name
    type   = "volume"
  }

  networks_advanced {
    name = docker_network.services_network.name
  }

  ports {
    internal = 3000
    external = 3000
  }
}

# Step 6: Prometheus Container Setup
resource "docker_container" "prometheus" {
  image = "prom/prometheus:latest"
  name  = "prometheus"
  restart = "always"

  # Correct volume attachment using mount
  mounts {
    target = "/prometheus"
    source = docker_volume.prometheus_volume.name
    type   = "volume"
  }

  networks_advanced {
    name = docker_network.services_network.name
  }

  ports {
    internal = 9090
    external = 9090
  }
}

# Step 7: Flask API Container Setup
resource "docker_container" "flask" {
  image = "python:3.9-slim"
  name  = "flask_api"
  restart = "always"

  networks_advanced {
    name = docker_network.services_network.name
  }

  ports {
    internal = 5000
    external = 5000
  }

  provisioner "local-exec" {
    command = <<EOT
      docker exec -it ${self.name} bash -c "
        pip install flask;
        echo 'from flask import Flask\napp = Flask(__name__)\n@app.route(\"/\")\ndef hello():\n return \"Hello from Flask!\"\nif __name__ == \"__main__\":\n app.run(host=\"0.0.0.0\", port=5000)' > app.py;
        python app.py"
    EOT
  }
}

# Step 8: Output the container URLs
output "jenkins_url" {
  value = "http://localhost:8080"
}

output "grafana_url" {
  value = "http://localhost:3000"
}

output "prometheus_url" {
  value = "http://localhost:9090"
}

output "flask_url" {
  value = "http://localhost:5000"
}
