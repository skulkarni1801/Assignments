terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.1.0"
    }
  }
}

# Configure the Google Provider
provider "google" {
 #credentials = file("C:\\Users\\sourabh.kulkarni\\AppData\\Roaming\\gcloud\\application_default_credentials.json")
 credentials = file("C:\\Sourabh\\Terraform\\JSONKey\\DemoProject\\Admin\\demoproject-333900-707891dcf155.json")
 project     = "demoproject-333900"
 region      = "us-west1"
}

/*
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}
*/

module vpc {
  source = "./modules/vpc"
}

resource "google_compute_instance" "default" {
 name         = "myfirsttfvm"
 machine_type = "f1-micro"
 zone         = "us-west1-a"

 boot_disk {
   initialize_params {
     image = "debian-cloud/debian-9"
   }
 }

// Make sure flask is installed on all new instances for later steps
 #metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python-pip rsync; pip install flask"

 network_interface {
   network = "default"

   access_config {
     // Include this section to give the VM an external ip address
   }
 }
}

