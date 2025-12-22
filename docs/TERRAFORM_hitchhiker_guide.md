# The Hitchhiker's Guide to Terraform

*Don't Panic. It's just graph theory wearing a hard hat.*

This guide explains how Terraform actually thinks - not how marketing describes it. Once you understand these concepts, Terraform becomes predictable, even boring. And boring infrastructure is the highest compliment.

**Terraform is best understood as a graph evolution engine.** This guide explains how to think in graphs when designing Terraform systems.

## About This Guide

**Why this exists:** Most Terraform tutorials teach you *how* to write code. This guide explains *why* Terraform works the way it does - the mental model, the underlying principles, the "metaphysics" of infrastructure as code. Once you understand the model, the syntax becomes obvious and the behavior becomes predictable.

**How to read it:** This is not a reference manual. Read it like a story - each part builds on the previous. Part 1 establishes the foundation (Three Worlds), Part 2 explains the philosophy (Metaphysics), Part 3 reveals the structure (Graph Theory). After that, dive into whichever topics interest you. The Quick Reference at the end summarizes everything.

**Who wrote it:** Created by Nino Kurtalj, 2025. Inspired by Douglas Adams' style of explaining complex things simply, with occasional irreverence.

---

## This Project's Structure

Before diving into Terraform theory, here's how this specific project is organized:

### The Execution Contract

**Terraform is always executed from `providers/`. The `terraform_ws/` directory is a child module and is never run directly.**

```text
terraform_demo/
├── providers/              ← ROOT MODULE (run terraform here)
│   ├── main.tf            ← calls module "../terraform_ws"
│   ├── variables.tf       ← input variable declarations
│   ├── outputs.tf         ← exports values from the module
│   ├── terraform.tfvars   ← actual variable values (gitignored)
│   └── terraform.tfstate  ← STATE LIVES HERE (gitignored)
│
└── terraform_ws/           ← CHILD MODULE (never run directly)
    ├── main.tf            ← resource definitions
    ├── variables.tf       ← module inputs
    └── outputs.tf         ← module outputs
```

Why this structure?

- **`providers/`** is the execution boundary. All `terraform` commands run here.
- **`terraform_ws/`** contains reusable infrastructure definitions, called as a module.
- State is owned by `providers/`, not by `terraform_ws/`.

### State Ownership

A critical concept: **the root module owns the state file**.

```text
providers/terraform.tfstate  ← This file "owns" all resources
     │
     └── Contains mappings for:
         ├── module.terraform_ws.aws_vpc.main
         ├── module.terraform_ws.aws_subnet.public
         ├── module.terraform_ws.aws_instance.bastion
         └── ... every resource, even those defined in child modules
```

Child modules (`terraform_ws/`) don't have their own state. When you call a module, its resources become part of the calling module's state, prefixed with the module path.

This is why:
- You run `terraform apply` in `providers/`, not in `terraform_ws/`
- State is stored in `providers/terraform.tfstate`
- Resource addresses look like `module.terraform_ws.aws_vpc.main`

### The Wrapper Scripts

This project includes shell scripts that handle all the execution details:

```bash
./scripts/deploy.sh      # Runs: terraform -chdir=providers apply
./scripts/destroy.sh     # Runs: terraform -chdir=providers destroy
```

You never need to `cd` into directories or remember paths. The scripts do it.

---

## Part 1: The Three Worlds of Terraform

Think of Terraform as a very pedantic accountant with a memory, a rulebook, and zero tolerance for hand-waving.

Terraform lives in **three worlds at once**:

### World 1: Configuration (what you wrote)

Your `.tf` files. This is a *desired state declaration*, not instructions. You're not saying "create this, then that." You're saying:

> "The universe should look like this."

Terraform doesn't care about your intentions - only the final shape you described.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abc123"
  instance_type = "t3.micro"
}
```

This doesn't mean "create an instance." It means "there must exist exactly one instance with these properties."

### World 2: State (what Terraform believes exists)

The `terraform.tfstate` file is Terraform's memory. It maps:

- Resource addresses (`aws_instance.web`)
- To real-world IDs (`i-0a123456`)
- Plus attributes (AMI, tags, IPs, etc.)

**Critical insight**: Terraform honors state more than reality. If state says something exists, Terraform assumes it exists - even if someone deleted it manually. This is why drift causes surprises.

Think of state as:

> "What Terraform *remembers* about the world, last time it checked."

### World 3: Reality (what actually exists)

AWS, Azure, GCP - the actual cloud. Terraform only sees reality when it refreshes state (during `plan` or `apply`).

---

## The Core Rule

**Terraform never compares configuration directly to reality.**

It always follows this path:

```
configuration → state → reality
```

That middle step is everything.

This is why:

- Deleting state is catastrophic (amnesia)
- Manual changes cause "drift" surprises
- Import exists (to teach Terraform about existing things)

---

## What Happens During `terraform plan`

1. Terraform loads configuration (your `.tf` files)
2. Terraform loads state (its memory)
3. Terraform refreshes state from the provider (unless disabled)
4. Terraform builds a diff: desired (config) vs known (state)

The plan shows:
- `+` create (exists in config, not in state)
- `~` modify (exists in both, but different)
- `-` destroy (exists in state, not in config)
- `-/+` replace (must destroy and recreate)

**Important**: Terraform doesn't ask "what's the safest change?" It asks:

> "What operations make state match configuration?"

If that means destruction, so be it.

---

## The Sentence That Unlocks Terraform

> Terraform files do not describe **what to do**. They describe **what must be true**.

Everything else follows from that.

Once this clicks, Terraform becomes predictable, even boring - which is exactly what you want when it controls reality.

---

## Part 2: The Metaphysics of Terraform

Now that you understand the Three Worlds, let's explore the deeper principles that govern how Terraform thinks. These concepts are the "physics" of Terraform's universe - understanding them makes everything else predictable.

### Idempotency - The Same Result, Every Time

**Idempotent** means: running an operation multiple times produces the same result as running it once.

```text
apply → state A
apply → state A (no change)
apply → state A (still no change)
```

This is fundamental to Terraform's design. Apply 10 times, apply 100 times - if your configuration hasn't changed and reality hasn't drifted, the result is always the same.

Why this matters:

- **Safe retries**: If `apply` fails halfway, run it again. Terraform picks up where it left off.
- **Predictability**: You can trust that extra applies don't cause unexpected changes.
- **Automation**: CI/CD pipelines can run `apply` repeatedly without fear.

Compare to imperative scripts:

```bash
# NOT idempotent - runs every time, creates duplicates
aws ec2 run-instances --image-id ami-123

# Terraform equivalent is idempotent
# "There must exist exactly one instance" - if it exists, do nothing
```

Scripts *do things*. Terraform *ensures states*. That's the difference.

### The Convergence Model

Terraform doesn't "execute commands" - it **converges reality toward a target state**.

Think of it like a thermostat:

```text
Target: 72°F
Current: 65°F
Action: Turn on heat

Target: 72°F
Current: 72°F
Action: Do nothing

Target: 72°F
Current: 78°F
Action: Turn on AC
```

Terraform works the same way:

```text
Desired: 3 instances
Current: 1 instance
Action: Create 2 more

Desired: 3 instances
Current: 3 instances
Action: Nothing

Desired: 3 instances
Current: 5 instances
Action: Destroy 2
```

The convergence model means:

- Terraform doesn't care *how* you got to the current state
- It only cares about *the gap* between desired and actual
- The action depends on the delta, not on history

This is why Terraform can:

- Recover from partial failures (just run again)
- Handle drift (reality changed outside Terraform)
- Be safely interrupted (convergence continues next run)

> Terraform is a feedback loop, not a script executor.

### The Refresh Cycle - When Terraform Sees Reality

Terraform doesn't watch reality continuously. It checks at specific moments.

**When refresh happens:**

1. **terraform plan** - Reads state, queries providers, compares to config
2. **terraform apply** - Implicitly runs plan first, then executes
3. **terraform refresh** - Explicitly updates state from reality (rarely needed directly)

**What refresh does:**

```text
Before refresh:
  State says: instance has tag "v1"
  Reality has: instance has tag "v2" (someone changed it)

After refresh:
  State says: instance has tag "v2"
  Config says: instance should have tag "v1"
  Plan says: Change tag from "v2" back to "v1"
```

Refresh is how Terraform discovers **drift** - when reality has changed outside of Terraform.

**Important insight:** Between applies, Terraform is blind. It operates on memory (state), not live observation. This is why:

- Manual changes cause surprises
- State should be the single source of truth
- `terraform plan` before `apply` is essential

### Why NOT Imperative

Scripts tell computers *what to do*. Terraform tells computers *what should exist*.

**Imperative (scripts):**

```bash
#!/bin/bash
# Create a VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)

# Create a subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' --output text)

# Launch an instance
aws ec2 run-instances --image-id ami-123 --subnet-id $SUBNET_ID
```

Problems with this approach:

| Problem | What goes wrong |
|---------|-----------------|
| Not idempotent | Run twice → two VPCs, two subnets |
| No state | Script doesn't remember what it created |
| No diffing | Can't see what would change before doing it |
| Ordering is manual | You manage dependencies in code |
| Partial failure | Script stops, resources orphaned |
| Destruction | Need a separate teardown script |

**Declarative (Terraform):**

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_instance" "web" {
  ami       = "ami-123"
  subnet_id = aws_subnet.public.id
}
```

What Terraform provides:

| Feature | What you get |
|---------|--------------|
| Idempotent | Run 100 times, same result |
| State tracking | Terraform remembers everything |
| Diffing | `plan` shows changes before applying |
| Automatic ordering | Dependencies derived from references |
| Convergent | Partial failures self-heal on next run |
| Unified lifecycle | Same code creates and destroys |

The imperative model fails at scale because:

- You can't diff a script against reality
- Scripts don't know what they've created
- Ordering becomes exponentially complex
- There's no feedback loop

Terraform succeeds because it's not executing commands - it's reconciling desired state with actual state, every single time.

### Single Source of Truth

In Terraform's model, the `.tf` configuration is the **single source of truth** for desired state.

What this means in practice:

| Change method | Result |
|---------------|--------|
| Edit `.tf` files | Terraform knows, can plan/apply |
| Click in AWS Console | Drift - Terraform will "fix" it next apply |
| Use AWS CLI directly | Drift - Terraform will overwrite it |
| Edit state file manually | Corruption - never do this |

The principle:

> If Terraform manages a resource, ALL changes go through Terraform.

Violating this principle causes:

- **Drift**: Reality doesn't match state or config
- **Surprises**: Plan shows changes you didn't expect
- **Conflicts**: Terraform undoes manual changes
- **Confusion**: "Who changed this? When?"

Why Terraform enforces this:

1. It enables the convergence model
2. It makes infrastructure auditable (changes in git)
3. It allows reliable `plan` output
4. It prevents "configuration by archaeology"

When you must make changes outside Terraform:

1. Make the emergency change
2. Update Terraform config to match
3. Run `terraform plan` to verify no diff
4. Commit the config change

Or use `terraform import` to bring existing resources under management.

### Identity vs Content

This is perhaps the most subtle concept: **Terraform identifies resources by address, not by content.**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abc123"
  instance_type = "t3.micro"
}
```

The **identity** is: `aws_instance.web`
The **content** is: ami, instance_type, etc.

Why this matters:

**Scenario 1: Change content, same identity**

```hcl
# Before
resource "aws_instance" "web" {
  instance_type = "t3.micro"
}

# After
resource "aws_instance" "web" {
  instance_type = "t3.small"
}
```

Terraform sees: Same resource (`aws_instance.web`), different attribute. Plan: modify in place.

**Scenario 2: Change identity, same content**

```hcl
# Before
resource "aws_instance" "web" { ... }

# After (renamed)
resource "aws_instance" "frontend" { ... }
```

Terraform sees: `aws_instance.web` deleted, `aws_instance.frontend` created. Plan: destroy and recreate. Even though the config is identical!

This is why `moved` blocks exist:

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.frontend
}
```

Now Terraform knows: same resource, new address.

**The deeper principle:**

State maps **addresses** to **real-world IDs**:

```
aws_instance.web → i-0abc123456
```

If you change the address without telling Terraform, it loses the mapping. The real resource becomes orphaned, and Terraform creates a duplicate.

| Change type | What happens |
|-------------|--------------|
| Change content only | Modify or replace (provider rules) |
| Change address only | Destroy + Create (data loss!) |
| Change both | Destroy + Create with new content |
| Use `moved` | Address changes, identity preserved |

Think of it like renaming a file vs editing a file:

- `mv config.tf settings.tf` - the file is "the same"
- But to a naive tool comparing filenames, `config.tf` disappeared and `settings.tf` appeared

Terraform has `moved` blocks so it's not naive about renames.

---

## Part 3: Terraform as Graph Theory

This is where Terraform stops being mysterious and starts feeling like applied computer science. Terraform is one of the best real-world examples of graph theory in action - if you understand graphs, you understand Terraform.

### What Is a Graph?

Before diving into Terraform specifics, let's establish the fundamentals.

A **graph** is a mathematical structure consisting of:

- **Vertices** (also called nodes) - the "things"
- **Edges** - connections between things

That's it. Everything else builds on this simple foundation.

```text
    A ─────── B
    │         │
    │         │
    C ─────── D
```

This is a graph with 4 vertices (A, B, C, D) and 4 edges connecting them.

### Directed vs Undirected Graphs

In an **undirected graph**, edges have no direction - if A connects to B, then B also connects to A. Think of a road that goes both ways.

In a **directed graph** (or "digraph"), edges have direction - A → B does not imply B → A. Think of a one-way street.

```text
Undirected:     Directed:
    A ─── B         A ──→ B

    (both ways)     (one way only)
```

**Terraform uses directed graphs.** The direction represents dependency: "A must exist before B can be created."

### Acyclic Graphs - The DAG

A **cycle** is a path that leads back to where it started:

```text
Cycle (forbidden):
    A ──→ B
    ↑     │
    │     ↓
    └──── C

A needs B, B needs C, C needs A... infinite loop!
```

An **acyclic graph** has no cycles - you can never follow edges and return to where you started.

A **DAG (Directed Acyclic Graph)** is a directed graph with no cycles.

**Terraform's dependency graph MUST be a DAG.** If Terraform detects a cycle, it stops with an error because no valid execution order exists.

### Why Terraform Must Be Acyclic

Consider what a cycle would mean:

```hcl
# IMPOSSIBLE - creates a cycle
resource "aws_instance" "web" {
  subnet_id = aws_subnet.app.id  # web needs subnet
}

resource "aws_subnet" "app" {
  # Imagine this somehow needed the instance
  depends_on = [aws_instance.web]  # subnet needs web
}
```

If web needs subnet, and subnet needs web, which do you create first? There's no answer. That's why cycles are forbidden.

### Blocks Are Vertices

Now let's map this to Terraform. When you write:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abc123"
  instance_type = "t3.micro"
}
```

You're declaring a **vertex** in Terraform's DAG.

Breaking it down:

| Part | Graph meaning | What it represents |
|------|---------------|-------------------|
| `resource` | Vertex category | This is a managed real-world object |
| `"aws_instance"` | Vertex type | Provider-defined type (like a class) |
| `"web"` | Vertex name | Local identity within Terraform |
| `{ ... }` | Vertex attributes | Constraints on the real-world object |

The full address becomes: `aws_instance.web`

That address is what Terraform tracks in state. Think of it as **coordinates**, not connections.

### References Create Edges

Edges only exist when one block references another:

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  # ...
}

resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id
  # ...
}
```

The line `subnet_id = aws_subnet.public.id` creates a **directed edge**:

```text
aws_subnet.public → aws_instance.web
```

The edge means: "This vertex depends on that vertex's value."

Terraform builds its dependency graph by scanning expressions for these references.


### Attributes Are NOT Edges

This is a common confusion. Attributes are:

- Internal data on the vertex
- Constraints on the real-world object
- Used for diffing (what changed?)

They live *inside* the vertex, not between vertices.


Only **references to other blocks** create edges.

### Degree Has Meaning

In Terraform's directed graph:

- **In-degree** = how many things this block depends on
- **Out-degree** = how many things depend on this block

#### Calculating In-Degree

```hcl
resource "aws_instance" "web" {
  subnet_id         = aws_subnet.public.id    # edge from subnet
  vpc_security_group_ids = [aws_security_group.web.id]  # edge from SG
  iam_instance_profile = aws_iam_instance_profile.app.name  # edge from IAM
}
```

In-degree = 3 (this instance waits for 3 other resources)

#### Calculating Out-Degree

```hcl
resource "aws_subnet" "public" { ... }

# This subnet is referenced by:
resource "aws_instance" "web1" { subnet_id = aws_subnet.public.id }
resource "aws_instance" "web2" { subnet_id = aws_subnet.public.id }
resource "aws_instance" "db"   { subnet_id = aws_subnet.public.id }
```

Out-degree = 3 (three things depend on this subnet)

#### Why Degree Matters

| Degree pattern | What it means | Risk |
|----------------|---------------|------|
| In-degree = 0 | Source vertex, can apply immediately | None |
| High in-degree | Late in execution, waits for many things | Slow to create |
| High out-degree | Structural keystone, many dependents | Dangerous to change |

High out-degree vertices (VPCs, shared subnets, IAM roles) are **structural keystones**. Refactoring them without `moved` blocks causes catastrophe.

### Sources and Sinks

- **Source vertices** (in-degree = 0): VPCs, base resources - can be applied immediately
- **Sink vertices** (out-degree = 0): Leaf resources, outputs - terminal nodes

**Example sources:**

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}  # in-degree = 0, can start immediately

data "aws_caller_identity" "current" {}  # read-only source
```

**Example sinks:**

```hcl
output "instance_ip" {
  value = aws_instance.web.public_ip
}  # out-degree = 0, nothing depends on this
```

### The Acyclicity Constraint

If Terraform detects a cycle:

```
A depends on B
B depends on A
```

It errors. No topological ordering exists, so no evaluation order is possible.

This is why:
- References must be acyclic
- Implicit dependencies matter
- "Just add depends_on" can backfire

### There Is No Universal Vertex

Terraform deliberately avoids having one vertex that everything depends on. Why?

- It would serialize execution
- Destroy parallelism
- Collapse the DAG into a chain

The **root module** contains all blocks but is the graph boundary, not a node inside it.

### Topological Sorting - How Terraform Orders Operations

This is the key algorithm that makes Terraform work. **Topological sorting** takes a DAG and produces an ordering where every vertex appears before all vertices that depend on it.

Consider this dependency chain:

```text
VPC → Subnet → Security Group → Instance
```

A topological sort produces: VPC, Subnet, Security Group, Instance

That's the creation order - each resource is created only after its dependencies exist.

**Why it works:**

1. Find all vertices with in-degree = 0 (no dependencies)
2. Process them (they can run in parallel!)
3. Remove them from the graph
4. Repeat until the graph is empty

If step 1 ever finds no vertices but the graph isn't empty, there's a cycle.

**Visual example:**

```text
Step 1: Find sources (in-degree = 0)
        VPC has in-degree 0 → process it

Step 2: Remove VPC, update degrees
        Subnet now has in-degree 0 → process it

Step 3: Remove Subnet, update degrees
        Security Group now has in-degree 0 → process it

Step 4: Remove SG, update degrees
        Instance now has in-degree 0 → process it

Done!
```

### Parallelism - The Power of the DAG

Here's why graphs matter for performance. Consider this configuration:

```text
                    ┌──→ Instance A
        ┌──→ Subnet ┤
VPC ────┤           └──→ Instance B
        │
        └──→ Security Group ──→ Instance C
```

Topological sort gives us **levels**:

| Level | Resources | Can run in parallel? |
|-------|-----------|---------------------|
| 0 | VPC | Only one, runs alone |
| 1 | Subnet, Security Group | YES - no dependency between them |
| 2 | Instance A, B, C | YES - no dependency between them |

Terraform's `-parallelism` flag (default 10) controls how many operations run simultaneously. The graph structure determines *what can* run in parallel - only independent vertices at the same level.

**This is why Terraform scales:**

- Wide graphs = more parallelism
- Linear chains = sequential execution
- Well-designed infrastructure has independent branches

### Destroy Order - Reverse Topological Sort

Creation order follows dependencies: create VPC before Subnet.

Destruction is the **reverse**: destroy Subnet before VPC.

Why? You can't delete a VPC that still has subnets in it. The cloud provider will reject the operation.

```text
Creation:   VPC → Subnet → Instance
Destruction: Instance → Subnet → VPC
```

Terraform automatically reverses the topological sort for `terraform destroy`.

**This is why `depends_on` affects destruction too:**

```hcl
resource "aws_instance" "app" {
  depends_on = [aws_iam_role.app]
}
```

- Creation: IAM role first, then instance
- Destruction: Instance first, then IAM role

If you get `depends_on` wrong, destruction may fail even if creation worked.

### Visualizing the Graph

Terraform can show you its dependency graph:

```bash
terraform graph
```

This outputs DOT format (Graphviz). To visualize:

```bash
# Generate PNG image
terraform graph | dot -Tpng > graph.png

# Generate SVG (better for large graphs)
terraform graph | dot -Tsvg > graph.svg
```

**What you'll see:**

- Rectangles = resources
- Ovals = data sources, outputs
- Arrows = dependencies (edge direction)

This is invaluable for debugging. If Terraform is doing something unexpected, visualize the graph.

### Edge Bounds - How Many Dependencies?

There is **no fixed upper bound** on vertex degree.

- A vertex can have 0, 1, 50, or 500 incoming edges
- A vertex can have 0, 1, 50, or 500 outgoing edges

Practical limits come from:

- Provider API limits (AWS has limits on attachments, rules, etc.)
- Execution parallelism (default 10)
- Human maintainability (high-degree nodes are hard to reason about)
- State size (huge fan-out increases state file size)

**Extreme cases:**

| Pattern | In-degree | Out-degree | Example |
|---------|-----------|------------|---------|
| Isolated | 0 | 0 | Unused resource |
| Source | 0 | many | VPC, shared IAM role |
| Sink | many | 0 | Output blocks |
| Hub | few | hundreds | Shared network module |

High out-degree vertices are **structural keystones**. Changing them ripples through everything that depends on them.

### The Graph Theory Summary

| Concept | In Terraform | Why it matters |
|---------|--------------|----------------|
| Vertex | Block (resource, data, output) | The "things" Terraform manages |
| Edge | Reference between blocks | Defines ordering and data flow |
| In-degree | Number of dependencies | How many things must exist first |
| Out-degree | Number of dependents | How many things break if this changes |
| Source | In-degree = 0 | Can be created immediately |
| Sink | Out-degree = 0 | Terminal node, nothing depends on it |
| DAG | Directed Acyclic Graph | The fundamental structure |
| Topological sort | Execution order | How Terraform determines what runs when |
| Cycle | Forbidden | No valid execution order exists |

If you understand these concepts, you understand how Terraform thinks.

---

## Part 4: State vs Graph - Orthogonal Dimensions

This is where many mental models break. State and graph are **orthogonal** - they exist in different conceptual dimensions.

| Aspect | Graph | State |
|--------|-------|-------|
| Answers | "What must exist, in what order?" | "Which real object is this?" |
| Derived from | `.tf` files, references | Provider responses |
| Nature | Structural, static, timeless | Historical, mutable |

They are **orthogonal** (separate design axes) but **not independent** (both affect outcomes):

```
outcome = f(graph, state, reality)
```

### You can change one without the other:

**Same graph, different state:**
- Import a resource → state changes, graph unchanged
- One state has object → modify; another has none → create

**Same state, different graph:**
- Refactor with `moved` → graph changes, state identity preserved
- Add new resource → graph grows, existing state unchanged

### Why this matters

Because graph and state are orthogonal, Terraform can:
- Refactor infrastructure without recreating it (`moved`)
- Adopt existing resources (`import`)
- Detect drift without changing intent

If they were not orthogonal, Terraform would be impossible to refactor safely.

---

## Part 5: The Five Power Features

These solve one problem: **Infrastructure changes over time, but identity must survive.**

### 1. Remote State

Local state is like keeping your brain in a text file on your laptop. Fine for experiments, catastrophic for teams.

Remote state means:
- State stored in shared backend (S3, GCS, etc.)
- Everyone sees the same truth
- Enables layered infrastructure via outputs

Why it matters:
- Teams can collaborate
- CI/CD can run safely
- Long-lived infrastructure survives laptop deaths

Hidden superpower: Remote state enables **outputs to be consumed by other stacks**. This is how you build layered infrastructure without copy-paste insanity.

> "Infrastructure RAM with persistence and locks."

### 2. State Locking

Terraform assumes only one actor modifies state at a time. State locking enforces this.

When enabled (almost always with remote state):
- Terraform acquires a lock before plan/apply
- Other runs block or fail
- No race conditions
- No half-written state

Without locking:
- Two applies run in parallel
- Both read old state
- Both apply different changes
- Last write wins
- Infrastructure reality loses

> If you disable locking, you volunteer for nondeterminism.

Locking is not optional in real systems. It's the mutex protecting reality.

### 3. Moved Blocks

Terraform identifies resources by **address**, not intent. Renaming without `moved` means:

```
aws_instance.web → aws_instance.app
```

Terraform thinks:
> "Old resource destroyed, new one created."

Moved blocks say: "This is the same thing, just renamed."

```hcl
moved {
  from = aws_instance.web
  to   = aws_instance.app
}
```

What you get:
- State continuity
- Resource identity preservation
- No downtime
- No data loss

These are **refactoring tools for infrastructure**. They let you clean up structure without changing reality.

### 4. Import

Terraform normally works like:

> "I create things, therefore I know them."

Import flips that:

> "This thing already exists. Learn it."

Import:
- Attaches existing real resource to Terraform state
- Does NOT change the resource
- Only teaches Terraform its ID and attributes

After import:
- Terraform manages the resource
- Future plans include it
- Drift becomes visible

Important subtlety: Import does NOT generate config automatically. You must:
1. Write matching `.tf`
2. Import the ID
3. Reconcile diffs

Import is how Terraform enters:
- Brownfield environments
- Legacy infrastructure
- "Someone-clicked-it-in-the-console" land

It's adoption, not creation.

### 5. Lifecycle Rules

These tell Terraform **how aggressive it's allowed to be**. They don't change desired state - they change behavior when reconciling.

**prevent_destroy**

```hcl
lifecycle {
  prevent_destroy = true
}
```

> "You may not destroy this. Ever."

Used for databases, critical networks, things lawyers care about.

**ignore_changes**

```hcl
lifecycle {
  ignore_changes = [tags]
}
```

> "I know this will drift. Ignore it."

Used when external systems modify fields, or providers report noisy diffs. This is *controlled blindness*, not laziness.

**create_before_destroy**

```hcl
lifecycle {
  create_before_destroy = true
}
```

> "Replace safely."

Terraform:
1. Creates new resource
2. Switches dependencies
3. Destroys old one last

Without this, replacement = downtime.

### How These Fit Together

These five are not random features. They solve one problem:

> **Infrastructure changes over time, but identity must survive.**

| Feature | What it provides |
|---------|------------------|
| Remote state | Shared memory |
| State locking | Safe concurrency |
| Moved blocks | Identity across refactors |
| Import | Adopt existing reality |
| Lifecycle rules | Control blast radius |

Once you use them properly, Terraform stops being scary. It becomes boring.

---

## Part 6: Terraform and Shell Scripts

Terraform and shell scripts have an uneasy, contractual relationship. Terraform tolerates scripts but:

- Does NOT trust them
- Does NOT reason about them
- Will pretend they don't exist after execution

### Terraform's Core Job vs Shell Scripts

**Terraform:**
```
declare → compare → converge
```

**Shell scripts:**
```
imperative → opaque → side-effectful
```

Terraform tolerates scripts only at the **edges**, never at the center.

### The Hierarchy of Script Integration

#### Best: User data / cloud-init

Terraform:
- Provisions infrastructure
- Injects a script
- The platform executes it at boot

Terraform does NOT run the script. It merely delivers it.

```hcl
resource "aws_instance" "web" {
  user_data = file("bootstrap.sh")
  # ...
}
```

Advantages:
- Reproducible
- Runs on every boot (if designed that way)
- Belongs to the resource lifecycle
- Terraform stays honest

#### Acceptable: External data source

Script runs, returns JSON, Terraform uses it as read-only input. No mutation, deterministic.

```hcl
data "external" "example" {
  program = ["python3", "get_data.py"]
}
```

Rules:
- Script must be deterministic
- No side effects
- Exit code matters
- Output must be machine-readable

This fits Terraform's model because there's no mutation, no hidden state.

#### Last resort: Provisioners

Terraform runs script, checks exit code, moves on. No tracking of what changed.

```hcl
provisioner "local-exec" {
  command = "echo 'This happened'"
}
```

What Terraform honors:
- Success = exit code 0
- Failure = non-zero

What Terraform ignores:
- What the script actually changed
- Whether it's idempotent
- Whether it partially succeeded
- Whether it will behave the same next time

This is why the docs quietly say:

> "Provisioners are a last resort."

They break Terraform's mental model.

### The Golden Rule

> Terraform only understands things it can model. Shell scripts have hidden state, mutate reality invisibly, and are not declarative.

Terraform's stance:

> "I will execute them, but I will not reason about them."

### When Shell Scripts Are Appropriate

**Good uses:**
- Bootstrapping via cloud-init
- One-time migrations
- Glue code around Terraform
- Read-only discovery
- Invoking configuration management tools

**Bad uses:**
- Ongoing configuration drift control
- Business logic
- Stateful orchestration
- Anything requiring rollback guarantees

### The Surgeon Analogy

If Terraform were a surgeon:
- Resources are organs
- State is the chart
- Shell scripts are "someone adjusted something after surgery"

Allowed. Never trusted.

---

## Part 7: File Semantics (What Files Actually Mean)

Terraform treats **all `.tf` files in a directory as one logical document**. Filenames are human convention, not semantic.

| File | Contains | Is NOT |
|------|----------|--------|
| `main.tf` | Resources, data sources, modules | An action file |
| `variables.tf` | Input declarations | Runtime parameters |
| `outputs.tf` | Exported facts | Actions |
| `versions.tf` | Constraints on versions | Logic |
| `terraform.tfvars` | Variable values | Configuration |
| `.tfstate` | Terraform's memory of reality | Desired state |

### The Three Layers

**1. Configuration (`.tf`)**
- Desired shape of the world
- Parameterized
- Declarative
- Timeless

**2. State (`.tfstate`)**
- Remembered reality
- Mutable
- Historical
- Fragile

**3. Execution (plan/apply)**
- Ephemeral
- Derived
- Deterministic
- Not stored (unless you save the plan)

### Variables: Not Commands, Just Parameters

```hcl
variable "env" {
  type    = string
  default = "dev"
}
```

Think of Terraform like this:

```
desired_state = f(configuration, variables)
```

Variables are:
- Not intentions
- Not runtime parameters
- Not commands

They are **free parameters of the state equation**.

Terraform does not ask *why* a variable has a value. It only cares that the value is known before planning.

### Outputs: Observations, Not Actions

```hcl
output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

Outputs:
- Expose values from the graph
- Can be consumed by humans or other Terraform stacks
- Do NOT change infrastructure

They are **observations**, not actions.

### Modules: Not Classes, Just Subgraphs

A module is NOT:
- A class
- A component
- A service

A module is:

> A pure function that returns resource graphs.

```hcl
module "network" {
  source = "./network"
  cidr   = "10.0.0.0/16"
}
```

Modules do NOT create isolation. They only:
- Namespace resources
- Pass variables
- Expose outputs

State is still global per root module.

So `module.network.aws_vpc.main` is just a longer address, not a separate universe.

Terraform honors **addresses**. Change the address → Terraform thinks it's a new object.

---

## Part 8: Why Terraform Sometimes Wants to Destroy Things

When Terraform's plan shows unexpected destruction, it's not being malicious. It's being consistent.

### Common Reasons

**Immutable attributes**

Some fields (AMI, subnet, disk type) can't change in place. Provider rules force replacement.

```
# forces replacement
~ ami = "ami-old" -> "ami-new"
```

**State drift**

Someone changed infrastructure manually. Terraform sees mismatch and wants to "correct" it.

**Moved/renamed resources**

If you rename a resource without `moved {}`, Terraform thinks:
> "Old resource deleted, new one created"

**Computed values changed**

Anything marked `Computed` may cause cascading diffs from provider-computed attributes.

### The Truth

Terraform is not being clever. It's being *consistent*.

It asks one question:
> "What operations make state match configuration?"

If destruction is the answer, that's what it proposes.

---

## Part 9: Mental Models That Work

### Terraform is like a build system

| Make | Terraform |
|------|-----------|
| Targets | Blocks |
| Prerequisites | References |
| Build cache | State |
| Diff | Plan |

### Terraform is like a constraint solver

- Resources are **constraints on reality**
- State is **cached solutions**
- Plan is **the diff between desired and known**

### What Terraform Understands

- Graphs
- Diffs
- Rules

### What Terraform Does NOT Understand

- Intent
- Safety
- Business impact

That's your job.

---

## Part 10: Providers - The Law of the Land

Terraform defers authority to providers.

If AWS says "this field forces replacement" → Terraform obeys.

If the provider has a bug → Terraform faithfully reproduces that bug.

Terraform is NOT a cloud abstraction layer. It is a **cloud compliance engine**.

Providers:
- Define schemas (what attributes exist)
- Define lifecycle rules (what forces replacement)
- Map Terraform operations to cloud APIs

Terraform itself doesn't know what a VPC is. The provider teaches it.

---

## Part 11: Terraform's Place in the Stack

Terraform is not a complete solution. It's a layer - and understanding where that layer begins and ends is essential.

### The Provisioning Boundary

Terraform's domain is **infrastructure provisioning**:

- Create the VPC
- Launch the instance
- Attach the disk
- Configure the network

Terraform stops at the OS boundary. It creates the machine, but doesn't care what runs inside it.

### Why This Boundary Exists

Terraform's model is **resource-centric**: it manages objects that have identity, can be created/destroyed, and exist independently.

Configuration management (Ansible, Chef, Puppet) is **state-centric**: it manages the continuous state of a running system - packages, files, services, users.

These are fundamentally different problems:

| Concern | Terraform | Configuration Management |
|---------|-----------|-------------------------|
| Question answered | "Does this thing exist?" | "Is this thing configured correctly?" |
| Frequency | Occasional (infra changes) | Continuous (drift correction) |
| Scope | Cloud resources | OS and application state |
| State model | Explicit state file | Agent-based or push-based |
| Rollback | Destroy and recreate | Revert configuration |

Trying to make Terraform do configuration management (or vice versa) fights both tools' designs.

### The Handoff

The clean model is a handoff:

```text
Terraform creates infrastructure
       ↓
Terraform outputs connection details
       ↓
Configuration management configures the system
       ↓
Application deployment puts code on the system
```

Each layer has its own state, its own lifecycle, its own expertise.

### Why Not One Tool?

Because the problems require different abstractions:

- **Terraform** thinks in resources and dependencies
- **Ansible** thinks in tasks and idempotent operations
- **Kubernetes** thinks in desired pod states
- **CI/CD** thinks in pipelines and stages

Each tool is excellent at its layer. No tool is excellent at all layers.

Terraform's power comes from doing one thing well: managing infrastructure resources with a declarative model and explicit state. It doesn't try to be everything - and that's a feature.

---

## The Summary

> A Terraform resource block declares a **vertex in a directed dependency graph**, uniquely identified by type and name, whose attributes constrain a real-world object, while edges are induced by references and represent dependency and data flow; the real-world identity is stored in state.

If that sentence makes sense, you understand Terraform more deeply than most people who use it daily.

---

## One Last Thing

If you respect Terraform's model, it becomes boring and reliable.

If you fight it, it becomes a chaos generator with receipts.

Choose boring.

---

## Quick Reference

### The Three Worlds
1. **Configuration** - what you wrote (`.tf` files)
2. **State** - what Terraform believes exists (`.tfstate`)
3. **Reality** - what actually exists (cloud provider)

### The Core Path

```text
configuration → state → reality
```

### The Metaphysics

**Idempotency:**
- Apply multiple times = same result as apply once
- Safe retries, predictable automation

**Convergence Model:**
- Terraform converges reality toward desired state
- Like a thermostat, not a script
- Actions depend on delta, not history

**Refresh Cycle:**
- Terraform checks reality during plan/apply
- Between applies, Terraform is blind (operates on state memory)
- This is how drift is discovered

**Declarative vs Imperative:**
- Scripts: "do these steps" (not idempotent, no state, manual ordering)
- Terraform: "this should exist" (idempotent, stateful, auto-ordering)

**Single Source of Truth:**
- All changes go through `.tf` files
- Manual changes = drift = surprises

**Identity vs Content:**
- Resources identified by address (`aws_instance.web`), not content
- Change address without `moved` = destroy + create
- Change content = modify or replace (provider rules)

### The Five Power Features
1. Remote state - shared memory
2. State locking - safe concurrency
3. Moved blocks - identity across refactors
4. Import - adopt existing reality
5. Lifecycle rules - control blast radius

### Graph Theory Basics

**Core concepts:**

- Graph = vertices (things) + edges (connections)
- Directed graph = edges have direction (A → B)
- DAG = Directed Acyclic Graph (no loops)

**Terraform mapping:**

- Blocks = vertices
- References = edges (direction = dependency flow)
- In-degree = how many dependencies
- Out-degree = how many dependents
- Source = in-degree 0 (can start immediately)
- Sink = out-degree 0 (nothing depends on it)

**Execution:**

- Topological sort = determines creation order
- Reverse topological sort = destruction order
- Parallelism = independent vertices run together
- Cycles = forbidden (no valid order exists)

**Visualize:** `terraform graph | dot -Tpng > graph.png`

### When Terraform Destroys
- Immutable attributes changed
- State drift (manual changes)
- Resource renamed without `moved`
- Computed values cascaded

### Shell Script Hierarchy
1. **Best**: User data / cloud-init
2. **OK**: External data source (read-only)
3. **Last resort**: Provisioners
