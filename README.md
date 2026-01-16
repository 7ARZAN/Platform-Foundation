# Platform Foundation | Inception of Things

[![K3s](https://img.shields.io/badge/Kubernetes-K3s-orange?logo=kubernetes)](https://k3s.io/)
[![Vagrant](https://img.shields.io/badge/Infrastructure-Vagrant-blue?logo=vagrant)](https://www.vagrantup.com/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-blue?logo=argo-cd)](https://argoproj.github.io/argo-cd/)

A professional, production-oriented implementation of a lightweight cloud-native platform. Developed as part of the Inception of Things curriculum, this project focuses on automating infrastructure, streamlining application delivery, and adhering to modern platform engineering principles.

---

## 🏗 Project Architecture

The platform is divided into three primary tiers, designed for reproducibility and scalability:

### **Part 1: K3s Cluster Infrastructure**
Automated provisioning of a multi-node Kubernetes cluster using **Vagrant** and **VirtualBox**.
- **Control Plane (`elakhfifS`)**: Dedicated K3s server managing the cluster state.
- **Worker Node (`elakhfifSW`)**: Scalable execution environment for containerized workloads.
- **Automation**: Custom shell scripts for zero-touch installation and secure SSH configuration.

### **Part 2: Application Delivery & Networking**
Implementation of high-availability application deployment and traffic management.
- **Manifest Management**: Standardized Kubernetes deployments and services.
- **Ingress Controller**: Traefik-based routing with support for multiple hostnames (`app1.com`, `app2.com`, `app3.com`).
- **Networking**: Private network configuration with dedicated IP management for inter-node communication.

### **Part 3: GitOps with ArgoCD**
Transition to a declarative, developer-centric platform using **k3d** and **ArgoCD**.
- **Ephemeral Clusters**: Local Kubernetes environments powered by Docker.
- **Continuous Delivery**: Fully automated GitOps pipeline using ArgoCD for state synchronization.
- **Self-Healing**: Automatic drift detection and correction between Git and the cluster.

---

## 🚀 Getting Started

### Prerequisites
- [Vagrant](https://www.vagrantup.com/downloads) & [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Docker](https://www.docker.com/get-started)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [k3d](https://k3d.io/)

### Installation

#### 1. Provision the Cluster (Part 1)
```bash
cd p1
vagrant up
```

#### 2. Deploy Applications (Part 2)
```bash
cd p2
# Access nodes and apply manifests
vagrant ssh elakhfifS
kubectl apply -f /vagrant/apps/
```

#### 3. Setup GitOps (Part 3)
```bash
cd p3/scripts
./bootstrap.sh
./cluster.sh
./argocd.sh
```

---

## 🛠 Tech Stack

| Component | Technology |
| :--- | :--- |
| **Orchestration** | K3s / k3d (Kubernetes) |
| **Virtualization**| Vagrant / VirtualBox / Docker |
| **GitOps** | ArgoCD |
| **Ingress** | Traefik |
| **Scripting** | Bash / Ruby |

---

## 🛡 Security & Best Practices
- **Infrastructure as Code (IaC)**: Fully reproducible environments via Vagrantfiles and manifests.
- **Isolation**: Private networking and node-specific roles.
- **Automation**: Minimal manual intervention during bootstrap and deployment.
- **Clarity**: Modular script design and clean configuration files.

---

## 🌟 Bonus Features
- **Centralized Monitoring**: Prometheus & Grafana stack (planned).
- **Cluster Visualization**: Kubernetes Dashboard integration.
- **Dynamic Scaling**: Automated worker node registration.
