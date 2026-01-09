# Infrastructure as Code Design

**Last Updated**: 2026-01-08

---

## System Architecture Diagrams

### Overall IaC Platform Architecture

```mermaid
graph TD
    subgraph "User Interface"
        CLI[Command Line Interface]
        AWXWeb[AWX Web Interface]
        Holmes[Holmes AWX Agent]
    end

    subgraph "Orchestration Layer"
        AWX[AWX Platform]
        LangGraph[LangGraph Workflow]
        LLM[LLM Orchestrator]
    end

    subgraph "Automation Layer"
        Ansible[Ansible]
        Terraform[Terraform]
        Packer[Packer]
    end

    subgraph "Infrastructure Layer"
        KVM[KVM/Libvirt]
        HyperV[Hyper-V]
        K3s[K3s Kubernetes]
    end

    subgraph "Target Infrastructure"
        VMs[Virtual Machines]
        Containers[Containers]
        Networks[Networks]
        Storage[Storage]
    end

    CLI --> Ansible
    CLI --> Terraform
    CLI --> Packer
    AWXWeb --> AWX
    Holmes --> LLM
    LLM --> LangGraph
    LangGraph --> AWX
    AWX --> Ansible
    AWX --> Terraform
    Ansible --> KVM
    Ansible --> HyperV
    Ansible --> K3s
    Terraform --> KVM
    Terraform --> HyperV
    Packer --> KVM
    Packer --> HyperV
    KVM --> VMs
    KVM --> Networks
    KVM --> Storage
    HyperV --> VMs
    HyperV --> Networks
    HyperV --> Storage
    K3s --> Containers
```

---

## Zero-Touch AD Deployment Flow

### Truly Headless AD Deployment Sequence

```mermaid
sequenceDiagram
    participant User
    participant Terraform
    participant CloudInit
    participant VM
    participant WinRM
    participant Ansible
    participant AD

    User->>Terraform: terraform apply
    Terraform->>VM: Create VM with Cloud-Init
    VM->>CloudInit: Boot and Initialize
    CloudInit->>VM: Configure Network (Static IP)
    CloudInit->>VM: Install OpenSSH Server
    CloudInit->>VM: Configure WinRM
    CloudInit->>VM: Create Automation Users
    CloudInit->>VM: Add SSH Keys
    CloudInit->>VM: Enable Services (RDP, WinRM, SSH)
    VM->>WinRM: WinRM Ready (Port 5985)
    WinRM->>Ansible: Connection Established
    Ansible->>VM: Configure Static IP
    Ansible->>VM: Rename Computer to AD01
    Ansible->>VM: Install AD Domain Services
    Ansible->>VM: Install DNS Server
    Ansible->>VM: Install Certificate Services
    Ansible->>VM: Promote to Domain Controller
    Ansible->>AD: Configure Domain (ad.bakerstreetlabs.io)
    Ansible->>AD: Create OUs and Users
    Ansible->>AD: Configure Services
    AD->>Ansible: Domain Controller Ready
    Ansible->>User: Deployment Complete (40 minutes)
```

---

## Golden Image Creation Flow

### Packer Image Building Process

```mermaid
graph TD
    Start[Start Packer Build] --> LoadISO[Load ISO Image]
    LoadISO --> CreateVM[Create VM Instance]
    CreateVM --> InstallOS[Install Operating System]
    InstallOS --> Unattended[Unattended Installation]
    Unattended --> Provision[Run Provisioners]
    Provision --> Updates[Install Windows Updates]
    Updates --> Features[Install Features]
    Features --> Security[Apply Security Baseline]
    Security --> Configure[Configure WinRM/SSH]
    Configure --> Software{Install Software?}
    Software -->|Yes| InstallSW[Install Software Packages]
    Software -->|No| Sysprep[Sysprep/Generalize]
    InstallSW --> Sysprep
    Sysprep --> Optimize[Optimize Image]
    Optimize --> Export[Export Image]
    Export --> QCow2{QCOW2 Format?}
    QCow2 -->|Yes| QCOW2Output[Output qcow2 File]
    QCow2 -->|No| VHDXOutput[Output VHDX File]
    QCOW2Output --> End[Golden Image Ready]
    VHDXOutput --> End
```

---

## AWX Workflow Orchestration

### Holmes AWX Agent Workflow

```mermaid
graph TD
    UserRequest[User Natural Language Request] --> LLM[LLM Orchestrator]
    LLM --> Interpret[Interpret Request]
    Interpret --> IdentifyTemplates[Identify AWX Job Templates]
    IdentifyTemplates --> CreateWorkflow[Create LangGraph Workflow]
    CreateWorkflow --> StateMachine[LangGraph State Machine]
    StateMachine --> Step1[Workflow Step 1]
    Step1 --> AWXAPI1[AWX API: Launch Job Template 1]
    AWXAPI1 --> Ansible1[Ansible Playbook Execution 1]
    Ansible1 --> Webhook1[Job Completion Webhook]
    Webhook1 --> Step2[Workflow Step 2]
    Step2 --> AWXAPI2[AWX API: Launch Job Template 2]
    AWXAPI2 --> Ansible2[Ansible Playbook Execution 2]
    Ansible2 --> Webhook2[Job Completion Webhook]
    Webhook2 --> Aggregate[Aggregate Results]
    Aggregate --> Notify[Notify User]
    Notify --> End[Workflow Complete]
```

---

## Terraform Infrastructure Provisioning Flow

### Terraform VM Provisioning Process

```mermaid
sequenceDiagram
    participant User
    participant Terraform
    participant Libvirt
    participant CloudInit
    participant VM
    participant Ansible

    User->>Terraform: terraform init
    Terraform->>Terraform: Initialize Provider Plugins
    User->>Terraform: terraform plan
    Terraform->>Terraform: Generate Execution Plan
    Terraform->>User: Show Planned Changes
    User->>Terraform: terraform apply
    Terraform->>Libvirt: Create Network (192.168.100.0/24)
    Libvirt-->>Terraform: Network Created
    Terraform->>Libvirt: Create Base Image Volume
    Libvirt-->>Terraform: Volume Created
    Terraform->>Libvirt: Create VM Disk (Clone Base)
    Libvirt-->>Terraform: Disk Created
    Terraform->>CloudInit: Generate user-data.yml
    Terraform->>CloudInit: Generate meta-data.yml
    Terraform->>Libvirt: Create VM Domain
    Libvirt->>VM: Boot VM with Cloud-Init
    VM->>CloudInit: Read Configuration
    CloudInit->>VM: Apply Network Config
    CloudInit->>VM: Configure WinRM/SSH
    CloudInit->>VM: Create Users
    VM->>Ansible: Ready for Configuration (WinRM/SSH)
    Terraform->>User: VM Provisioned (5 minutes)
    User->>Ansible: Run Configuration Playbook
    Ansible->>VM: Configure Applications
    VM->>Ansible: Configuration Complete
    Ansible->>User: Deployment Complete
```

---

## Ansible Playbook Execution Flow

### AD Domain Controller Configuration Playbook

```mermaid
graph TD
    Start[Start Playbook] --> Inventory[Load Inventory]
    Inventory --> Connect[Connect via WinRM]
    Connect --> Wait[Wait for WinRM Ready]
    Wait --> Network[Configure Network Interface]
    Network --> StaticIP[Set Static IP 192.168.0.65]
    StaticIP --> Rename[Rename Computer to AD01]
    Rename --> InstallAD[Install AD Domain Services]
    InstallAD --> InstallDNS[Install DNS Server]
    InstallDNS --> InstallCA[Install Certificate Services]
    InstallCA --> Promote[Promote to Domain Controller]
    Promote --> Domain[Configure Domain ad.bakerstreetlabs.io]
    Domain --> OUs[Create Organizational Units]
    OUs --> Users[Create Users and Groups]
    Users --> Services[Configure Services]
    Services --> Verify[Verify Domain Controller]
    Verify --> Complete[Configuration Complete]
    Complete --> End[End Playbook]
```

---

## AWX Platform Architecture

### AWX Component Interaction

```mermaid
graph TD
    subgraph "Kubernetes Cluster (K3s)"
        subgraph "Namespace: awx"
            AWXWeb[AWX Web<br/>nginx + uwsgi + receptor]
            AWXTask[AWX Task<br/>receptor + ansible-runner]
            AWXOperator[AWX Operator]
        end
        
        subgraph "PostgreSQL"
            PG[(PostgreSQL 15<br/>guacamole_db)]
        end
        
        subgraph "Redis"
            Redis[(Redis<br/>Cache + Message Broker)]
        end
        
        subgraph "Traefik Ingress"
            Traefik[Traefik<br/>HTTPS Termination]
        end
    end

    subgraph "External Services"
        User[User Browser]
        Holmes[Holmes AWX Agent]
        Ansible[Ansible Playbooks]
    end

    User -->|HTTPS| Traefik
    Traefik -->|HTTPS| AWXWeb
    Holmes -->|API| AWXWeb
    AWXWeb --> AWXTask
    AWXTask --> Ansible
    AWXWeb --> PG
    AWXTask --> PG
    AWXWeb --> Redis
    AWXTask --> Redis
    AWXOperator --> AWXWeb
    AWXOperator --> AWXTask
```

---

## Infrastructure Layers

### Multi-Layer Infrastructure Architecture

```mermaid
graph TB
    subgraph "Orchestration Layer"
        AWX[AWX Platform]
        Holmes[Holmes Agent]
    end

    subgraph "Automation Layer"
        Ansible[Ansible Playbooks]
        Terraform[Terraform Configs]
        Packer[Packer Templates]
    end

    subgraph "Provisioning Layer"
        Libvirt[Libvirt/KVM]
        HyperV[Hyper-V]
        K3s[K3s]
    end

    subgraph "Compute Layer"
        VMs[Virtual Machines]
        Containers[Containers]
        Physical[Physical Servers]
    end

    subgraph "Network Layer"
        Networks[Networks]
        SecurityGroups[Security Groups]
        LoadBalancers[Load Balancers]
    end

    subgraph "Storage Layer"
        Disks[Disks]
        Volumes[Volumes]
        Snapshots[Snapshots]
    end

    AWX --> Ansible
    Holmes --> AWX
    Ansible --> Libvirt
    Ansible --> HyperV
    Ansible --> K3s
    Terraform --> Libvirt
    Terraform --> HyperV
    Packer --> Libvirt
    Packer --> HyperV
    Libvirt --> VMs
    Libvirt --> Networks
    Libvirt --> Disks
    HyperV --> VMs
    HyperV --> Networks
    HyperV --> Disks
    K3s --> Containers
    K3s --> Volumes
    VMs --> Physical
    Containers --> Physical
```

---

## Workflow State Machine

### LangGraph Workflow State Machine

```mermaid
stateDiagram-v2
    [*] --> Initializing
    Initializing --> Parsing: Parse Request
    Parsing --> Planning: Create Workflow Plan
    Planning --> Executing: Start Execution
    Executing --> JobRunning: Launch AWX Job
    JobRunning --> JobRunning: Monitor Progress
    JobRunning --> JobComplete: Job Success
    JobRunning --> JobFailed: Job Failure
    JobComplete --> NextStep: Check for Next Step
    JobFailed --> Retry: Retry Logic
    Retry --> JobRunning: Retry Job
    Retry --> Failed: Max Retries
    NextStep --> Executing: More Steps
    NextStep --> Aggregating: All Steps Complete
    Failed --> Aggregating: Fail Fast
    Aggregating --> Complete: Workflow Complete
    Complete --> [*]
```

---

## Network Topology

### Cyber Range Network Architecture

```mermaid
graph TD
    subgraph "Core Infrastructure (192.168.0.0/24)"
        AWX[AWX 192.168.0.75]
        Portal[Portal 192.168.0.10]
        DNS1[DNS NS1 192.168.0.11]
        DNS2[DNS NS2 192.168.0.12]
    end

    subgraph "KVM Network (192.168.100.0/24)"
        KVMHost[KVM Host]
        AD01[AD01 192.168.0.65]
        AD02[AD02 192.168.0.66]
        VMs[Other VMs]
    end

    subgraph "Hyper-V Network"
        HyperVHost[Hyper-V Host]
        WinVMs[Windows VMs]
    end

    subgraph "Range Networks (172.22.0.0/24 - 172.30.0.0/24)"
        RangeVMs[Range VMs]
        Firewalls[Firewalls]
    end

    AWX --> AD01
    AWX --> AD02
    AWX --> VMs
    Portal --> AD01
    Portal --> AD02
    DNS1 --> AD01
    DNS2 --> AD02
    KVMHost --> AD01
    KVMHost --> AD02
    KVMHost --> VMs
    HyperVHost --> WinVMs
    AD01 --> RangeVMs
    AD02 --> RangeVMs
    Firewalls --> RangeVMs
```

---

**Maintained By**: Baker Street Labs Infrastructure Team

