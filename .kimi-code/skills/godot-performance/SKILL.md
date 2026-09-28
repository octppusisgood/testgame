---
name: godot-performance
description: >
  Audit and optimize performance in Godot 4.x projects, especially 3D projects.
  Use profiler-driven diagnosis to identify CPU, GPU, rendering, physics, scripting,
  memory, scene-tree, asset, and draw-call bottlenecks. Prefer measured evidence
  over generic optimization advice.
---

# Godot Performance Optimization Skill

## Purpose

This skill is for diagnosing and improving runtime performance in Godot 4.x projects.

Primary goals:

- Identify the actual bottleneck before proposing changes.
- Distinguish CPU, GPU, rendering-thread, physics, scripting, memory, and asset bottlenecks.
- Detect structural performance problems from project files when runtime profiling data is unavailable.
- Produce actionable findings ranked by severity and confidence.
- Avoid optimization work that adds complexity without measurable benefit.
- Preserve project behavior unless the user explicitly asks for architectural changes.

This skill is optimized for:

- Godot 4.x
- 3D projects
- Forward+, Mobile, and Compatibility renderers
- Desktop, mobile, embedded, and Web exports
- GDScript and mixed GDScript/C# projects
- Projects containing large scenes, many repeated objects, skeletal meshes, physics bodies, shaders, particle systems, or dynamic lighting

---

# Core Principle

Do not optimize by folklore.

Always prefer:

1. measured frame-time data,
2. profiler evidence,
3. reproducible scene-level evidence,
4. static project inspection,
5. only then general heuristics.

Never treat a metric such as draw calls, node count, triangle count, or VRAM usage as inherently bad without considering frame time and target hardware.

A project with 2500 draw calls at 6 ms render-thread time may be healthy.

A project with 800 draw calls at 15 ms render-thread time may already be CPU-bound.

---

# Required Diagnostic Order

When investigating a performance problem, analyze in this order.

## 1. Define target

Determine or infer:

- target platform,
- target frame rate,
- target resolution,
- renderer,
- representative scene,
- worst-case scene,
- minimum hardware target.

If unspecified, assume:

- Desktop PC
- 1920×1080
- 60 FPS
- Godot 4.x Forward+
- release/export build rather than editor runtime

Mark these assumptions explicitly.

Frame budgets:

| Target FPS | Total frame budget |
|---|---:|
| 30 FPS | 33.33 ms |
| 60 FPS | 16.67 ms |
| 90 FPS | 11.11 ms |
| 120 FPS | 8.33 ms |
| 144 FPS | 6.94 ms |

Do not recommend subsystem budgets whose sum exceeds the total frame budget.

---

## 2. Determine bottleneck class

Classify the dominant bottleneck before suggesting optimizations.

Possible classes:

- CPU game-thread bound
- CPU render-thread bound
- GPU bound
- physics bound
- scripting bound
- synchronization/stall bound
- memory/VRAM pressure
- streaming/loading bound
- mixed bottleneck
- insufficient evidence

Use the following interpretation.

### GPU-bound indicators

Typical signs:

- GPU frame time > CPU frame time
- Lowering resolution materially improves FPS
- Reducing shadow resolution improves FPS
- Reducing MSAA improves FPS
- Disabling expensive shaders improves FPS
- Heavy transparency or overdraw
- Expensive post-processing
- Large shadowed-light coverage

Prioritize:

- shaders
- shadow cost
- overdraw
- transparency
- post processing
- resolution
- MSAA
- volumetrics
- texture bandwidth
- geometry load
- LOD

Do not prioritize draw-call reduction unless CPU render submission is also expensive.

### CPU render-thread bound indicators

Typical signs:

- render-thread frame time is high
- many draw submissions
- many materials/surfaces
- large numbers of independent MeshInstance3D nodes
- many shadow passes
- excessive state changes
- weak batching/instancing opportunities
- large visible-object count

Prioritize:

- MultiMeshInstance3D
- mesh surface reduction
- material consolidation
- visibility culling
- LOD
- reducing shadow casters
- reducing independently submitted objects

### Script-bound indicators

Typical signs:

- script profiler dominates frame
- many `_process()` calls
- large per-frame loops
- repeated tree traversal
- repeated allocations
- excessive Dictionary/Array churn
- string building in hot paths
- frequent `get_node()` or dynamic lookup in tight loops
- many signals emitted every frame

Prioritize:

- event-driven updates
- cache references
- reduce per-frame allocations
- reduce polling
- update at lower cadence
- move fixed-rate work to `_physics_process()` only when appropriate
- batch work
- use typed data where useful
- consider C# or native code only after profiling proves GDScript itself is limiting

### Physics-bound indicators

Typical signs:

- physics time is high
- many active rigid bodies
- large contact counts
- concave collision on moving objects
- complex mesh collision
- high physics tick rate
- many raycasts/shapecasts every tick
- unnecessary continuous collision detection

Prioritize:

- simplify collision shapes
- use primitive/convex shapes
- reduce active-body count
- sleep inactive objects
- reduce physics tick rate when acceptable
- reduce query frequency
- avoid trimesh collision for dynamic bodies where possible

---

# Static Project Audit

When repository access is available, inspect the project before proposing broad optimization work.

Important files:

- `project.godot`
- `*.tscn`
- `*.scn`
- `*.tres`
- `*.res`
- `*.gd`
- `*.cs`
- `*.gdshader`
- imported mesh/resource metadata when available

Do not modify `.godot/` generated cache files unless explicitly required.

---

# project.godot Audit

Check for:

- renderer selection
- MSAA
- TAA
- FSR/scaling settings
- shadow atlas configuration
- physics tick rate
- max FPS
- VSync behavior
- viewport scaling
- texture filtering defaults
- threading-related settings
- environment defaults
- rendering method
- mobile renderer usage

Do not change global settings merely to improve benchmark numbers.

Explain visual or simulation tradeoffs.

---

# Scene Tree Audit

Look for structural patterns such as:

- thousands of `MeshInstance3D`
- many repeated identical meshes
- many nodes with scripts implementing `_process()`
- many dynamic lights
- many shadow-casting lights
- many `AnimationPlayer` or `AnimationTree` nodes
- many active `RigidBody3D`
- repeated high-cost particle systems
- excessive nested Viewports/SubViewports
- many decals
- large numbers of labels/control nodes in 3D interfaces
- duplicated materials
- large hidden subtrees still processing

Important distinction:

Node count alone is not a performance bug.

Flag node count only when there is a plausible hot-path consequence.

---

# Draw Call Analysis

Treat draw calls as a CPU/render-submission metric, not as an absolute quality score.

## Practical starting budgets

These are diagnostic heuristics only.

| Target | Typical comfortable range |
|---|---:|
| low-end mobile / Web | under ~500 |
| mid/high-end mobile | under ~800–1200 |
| desktop 3D | under ~1500–2500 |
| high-end desktop | ~3000–5000 may still be acceptable |

Do not flag a scene purely because it exceeds these numbers.

Require one or more of:

- high render-thread frame time,
- high CPU frame time,
- excessive surface/material count,
- visible repeated-object pattern,
- evidence of shadow-pass multiplication,
- target platform constraints.

---

# Mesh Surface and Material Analysis

One visible object may produce multiple draw calls.

Approximate:

`base draw submissions ≈ visible mesh instances × visible surfaces`

Additional passes may multiply this:

- shadow pass
- depth prepass
- transparency
- material next-pass
- outline/custom pass
- multiple viewports
- reflection/probe rendering

Example:

100 characters × 5 surfaces × base pass + shadow pass

may already approach:

`100 × 5 × 2 = 1000 submissions`

before other passes.

Flag unusually high surface counts on frequently repeated meshes.

Suggested severity:

- 1–3 surfaces: normally fine
- 4–6 surfaces: review if heavily instanced
- 7–12 surfaces: likely worth investigation
- >12 surfaces: high priority if frequently visible

Do not merge materials if it harms authoring, visual quality, shader behavior, or texture memory more than it helps.

---

# MultiMesh Analysis

Strong candidate for `MultiMeshInstance3D` when many objects:

- share the same mesh,
- share compatible material state,
- differ mainly by transform,
- are rendered in large quantities.

Examples:

- grass
- trees
- rocks
- bolts
- decorative props
- debris
- repeated building details
- particles represented as meshes
- crowds with limited variation

Potential transformation:

Before:

- 1000 MeshInstance3D nodes
- potentially ~1000 base submissions

After:

- one or a few MultiMesh batches

Do not recommend MultiMesh when objects require:

- unique materials,
- unique per-object render state,
- independent visibility rules that would negate batching,
- substantially different meshes,
- per-object skeletal animation,
- frequent arbitrary topology changes.

Mention that per-instance custom data may preserve controlled variation.

---

# Lighting and Shadow Audit

Dynamic shadows can multiply rendering cost significantly.

Inspect:

- number of visible DirectionalLight3D
- number of OmniLight3D
- number of SpotLight3D
- which lights cast shadows
- shadow distance
- shadow atlas size
- light radius
- overlap
- shadow caster count
- static vs dynamic geometry

Important:

An OmniLight3D shadow may require rendering multiple cubemap faces.

Therefore a small number of point lights can create substantial shadow rendering work.

Flag:

- many overlapping shadowed OmniLights
- large-radius shadowed lights
- decorative lights casting shadows unnecessarily
- distant geometry casting high-cost shadows
- high-resolution shadows with little visible benefit

Prefer:

- disable unnecessary shadows
- narrow light influence
- bake lighting where appropriate
- reduce shadow distance
- use lower shadow quality where visually acceptable

---

# Transparency and Overdraw Audit

Transparency may cause:

- poor batching
- sorting overhead
- large fragment cost
- heavy overdraw
- limited early-z rejection

Investigate:

- large transparent quads
- foliage
- particle effects
- overlapping UI
- transparent decals
- transparent full-screen effects
- alpha-blended materials on objects that could use alpha scissor

Prefer alpha scissor or opaque rendering when visually acceptable.

Do not change rendering mode blindly.

---

# Shader Audit

Review `*.gdshader` files for:

- large loops
- multiple texture samples
- trigonometric functions in fragment shader
- expensive noise functions
- repeated normalization
- dynamic branching
- screen texture reads
- depth texture reads
- many dependent texture reads
- unnecessary per-fragment work
- large transparent coverage

Classify work by stage.

Prefer moving calculations from fragment to vertex when interpolation is visually acceptable.

Do not alter shader semantics without explaining the visual impact.

---

# Geometry Audit

Triangle count is not sufficient by itself.

Consider:

- visible triangles
- small-triangle density
- vertex transform cost
- skinning
- overdraw
- shadow rendering
- LOD availability
- repeated geometry
- culling granularity

Flag high-poly meshes when:

- they occupy small screen area,
- are repeated frequently,
- render into multiple shadow passes,
- contain unnecessary hidden detail,
- lack LOD.

Prefer LOD before destructive simplification.

---

# LOD Audit

Check whether large scenes use:

- mesh LODs
- visibility ranges
- HLOD-like grouping
- impostors where appropriate
- reduced animation complexity at distance

A scene with many distant high-detail meshes is a high-value optimization target.

Recommend transitions that avoid visible popping.

---

# Occlusion and Visibility Audit

Check for:

- indoor scenes with many rooms
- cities
- dense environments
- large static architecture
- many objects outside the visible area

Possible tools:

- visibility ranges
- frustum culling
- occlusion culling
- spatial partitioning
- manual sector/room activation

Do not assume occlusion culling is always beneficial.

It can add overhead in sparse scenes.

---

# Script Audit

Inspect GDScript/C# for hot-path patterns.

## High-priority patterns

- `_process()` on hundreds/thousands of nodes
- `_physics_process()` used for non-physics work
- scene-tree traversal every frame
- `get_nodes_in_group()` every frame
- repeated `find_child()`
- repeated dynamic path lookup
- large allocations every frame
- repeatedly recreating arrays/dictionaries
- repeated string concatenation
- frequent resource loading during gameplay
- excessive signal emission
- calling expensive utility functions per object per frame

Prefer:

- caching
- event-driven updates
- lower-frequency updates
- centralized managers only when beneficial
- data-oriented batch processing where suitable
- object pooling where creation/destruction is actually expensive

Do not introduce pooling automatically.

Pooling can increase complexity and memory consumption.

---

# Process Frequency

Not all logic requires per-frame execution.

Possible update cadences:

- every frame
- every physics tick
- 10–30 Hz
- 1–5 Hz
- event-driven
- only when visible
- only when state changes

Examples suitable for lower-frequency updates:

- distant AI
- UI statistics
- environment scanning
- path reevaluation
- telemetry
- decorative animation logic
- background systems

Do not lower update frequency for control loops requiring deterministic high-rate behavior.

---

# Physics Audit

Inspect:

- `RigidBody3D`
- `CharacterBody3D`
- `StaticBody3D`
- collision shapes
- raycasts
- shapecasts
- Area3D usage
- contact monitoring
- CCD
- physics tick rate

Avoid dynamic concave trimesh collision when simpler collision works.

Prefer:

- BoxShape3D
- SphereShape3D
- CapsuleShape3D
- ConvexPolygonShape3D

when appropriate.

Flag excessive collision complexity on small or frequently moving objects.

---

# Animation and Skeleton Audit

Review:

- skeleton bone count
- visible skinned meshes
- animation update count
- AnimationTree complexity
- IK systems
- retargeting
- blend trees
- off-screen animation

Potential optimizations:

- stop or reduce updates for invisible characters
- reduce distant animation rate
- simplify rigs for LOD characters
- disable expensive IK at distance
- reduce number of simultaneously active animated characters

Do not recommend reducing bone count without evidence.

---

# Particle Audit

Investigate:

- particle count
- transparency
- collision
- trails
- large screen coverage
- high overdraw
- expensive shaders

GPUParticles3D is normally preferable for large visual-only particle counts.

Do not move gameplay-critical simulation to GPU particles if CPU-side deterministic interaction is required.

---

# Texture and VRAM Audit

Check:

- unusually large textures
- missing mipmaps
- uncompressed textures
- duplicated textures
- texture import settings
- excessive normal-map resolution
- large environment maps
- large shadow maps
- excessive render-target size

General VRAM guidance:

Try to keep sustained usage below roughly 70–80% of available VRAM on the minimum target GPU.

This is only a safety margin, not a strict requirement.

Memory pressure may cause:

- stutter
- driver paging
- texture eviction
- instability
- poor performance spikes

---

# Loading and Stutter Audit

Differentiate low average FPS from frame-time spikes.

Look for:

- synchronous resource loading
- shader compilation
- scene instantiation spikes
- runtime texture import/decompression
- garbage/refcount churn
- large node subtree insertion
- navigation rebuilds
- physics object bursts

Recommend preloading or threaded loading when appropriate.

Do not disguise long loading work by splitting it across frames unless user experience improves.

---

# Editor vs Exported Build

Never draw final performance conclusions from editor runtime alone.

Prefer:

- exported release build
- representative target hardware
- production rendering settings

Editor tooling may add substantial overhead.

If profiling data is only from the editor, mark conclusions as provisional.

---

# Profiling Procedure

When runtime access is available, gather:

1. average FPS
2. 1% low / worst frame time if available
3. CPU frame time
4. GPU frame time
5. render-thread time
6. script time
7. physics time
8. draw calls
9. objects drawn
10. primitives/triangles
11. VRAM usage
12. RAM usage

Test at least:

- representative normal scene
- worst-case scene
- camera facing dense content
- camera facing sparse content

Useful controlled experiments:

### Resolution test

Reduce resolution significantly.

If FPS improves substantially:

- suspect GPU bottleneck.

If little change:

- suspect CPU/render/physics/script bottleneck.

### Shadow test

Disable shadows temporarily.

Large gain:

- shadow rendering is significant.

### Material/shader test

Replace expensive material with simple material.

Large gain:

- shader/fragment cost is significant.

### Visibility test

Hide large object groups.

Use binary search over scene groups to isolate expensive content.

### Physics test

Pause/disable nonessential simulation.

Large gain:

- physics or gameplay logic is implicated.

---

# Severity Ranking

Every audit finding should include:

- severity
- confidence
- evidence
- expected impact
- suggested action
- tradeoffs
- validation method

Use:

## CRITICAL

Likely primary bottleneck or severe architectural issue.

Examples:

- synchronous multi-hundred-ms resource load during gameplay
- thousands of repeated independent meshes causing render-thread saturation
- pathological shader dominating GPU frame
- runaway physics workload

## HIGH

Strong evidence of meaningful frame-time impact.

## MEDIUM

Likely optimization opportunity but not proven to dominate frame time.

## LOW

Cleanup or preventive recommendation.

Do not label general style preferences as performance issues.

---

# Confidence Levels

Use:

- High confidence
- Medium confidence
- Low confidence

Example:

`HIGH severity / High confidence`

because:

- 1800 identical MeshInstance3D nodes use the same mesh and material,
- render-thread time is 12.4 ms,
- replacing them with a temporary MultiMesh reduces render-thread time to 4.1 ms.

That is much stronger than:

`HIGH severity / Low confidence`

because node count appears large.

---

# Required Finding Format

Use this structure:

```text
[HIGH] Repeated mesh instances are causing excessive render submissions
Confidence: High

Evidence:
- 1,873 MeshInstance3D nodes reference res://props/bolt.glb
- 1 material is shared
- all instances are static
- render-thread time: 11.8 ms
- draw calls: 2,406

Impact:
Likely CPU render-thread bottleneck.

Recommendation:
Replace the repeated nodes with one or several MultiMeshInstance3D batches.

Tradeoffs:
Per-instance node logic and independent visibility control become less convenient.

Validation:
Compare render-thread frame time and draw calls before and after the change.
```

---

# Performance Budget Guidance

Budgets are starting points only.

## Desktop 60 FPS

Typical healthy starting target:

- total frame: <16.67 ms
- CPU game logic: preferably <8–10 ms
- render thread: preferably <5–8 ms
- GPU: preferably <12–14 ms
- physics: preferably <2–3 ms
- script: preferably <2–4 ms

These subsystem figures are not additive hard limits.

They overlap depending on threading and pipeline behavior.

## Mobile 60 FPS

Aim for substantially more margin.

Prefer:

- fewer draw calls
- fewer dynamic lights
- cheaper shaders
- lower overdraw
- fewer shadow casters
- reduced render resolution where appropriate

Thermal stability matters.

A scene that runs at 60 FPS for 20 seconds but throttles after several minutes is not optimized.

---

# Renderer-Specific Notes

## Forward+

Best fit for:

- desktop
- high-end devices
- visually complex scenes

Watch:

- many dynamic lights
- shadow cost
- post-processing
- volumetrics
- expensive shaders

## Mobile

Best fit for:

- mobile GPUs
- simpler scenes
- lower overhead

Watch:

- shader compatibility
- light limits
- bandwidth
- tile-based GPU behavior
- transparency and overdraw

## Compatibility

Used for:

- older hardware
- broad compatibility
- some Web/OpenGL scenarios

Watch:

- renderer-specific limitations
- driver overhead
- feature differences
- material behavior

Do not recommend switching renderer unless the tradeoff is clearly justified.

---

# Safe Modification Rules

When editing a project:

1. Preserve behavior unless optimization requires a behavior change.
2. Make one optimization class at a time where practical.
3. Do not combine unrelated refactors with performance changes.
4. Do not replace systems solely because another language/framework is theoretically faster.
5. Avoid visual regressions unless explicitly accepted.
6. Avoid deleting assets unless requested.
7. Do not edit imported/generated cache files as source-of-truth.
8. Prefer reversible changes.
9. Record changed files.
10. Explain how to benchmark before and after.

---

# Optimization Validation

Every optimization should have a measurable success criterion.

Examples:

- render-thread time reduced from 10.2 ms to <6 ms
- GPU frame time reduced from 17 ms to <12 ms
- draw calls reduced from 3200 to <1800
- frame-time spikes reduced below 25 ms
- physics time reduced from 6 ms to <2 ms
- loading hitch reduced from 180 ms to <30 ms

Do not claim success from code inspection alone.

---

# False Positives to Avoid

Do not automatically flag:

- many nodes
- many triangles
- many draw calls
- GDScript usage
- signals
- inheritance
- resources
- shaders
- 4K textures

These are only problems when usage patterns and profiling evidence support the conclusion.

Do not recommend:

- C++/GDExtension merely because GDScript exists
- MultiMesh for objects requiring unique behavior
- merging all materials blindly
- disabling all shadows
- lowering physics tick rate for precision-critical simulation
- reducing texture resolution without screen-space justification
- removing visual effects without measuring their cost

---

# Repository Audit Workflow

When asked to audit a repository:

## Phase 1 — Project inventory

Identify:

- Godot version
- renderer
- language
- main scene
- large scenes
- shaders
- mesh-heavy directories
- gameplay scripts
- physics-heavy systems

## Phase 2 — Static risk scan

Search for:

- large repeated node groups
- repeated mesh resources
- scripts with `_process`
- scripts with `_physics_process`
- per-frame tree searches
- runtime loads
- many lights
- shadowed lights
- particle-heavy scenes
- many surfaces/materials
- SubViewport usage
- expensive shader patterns

## Phase 3 — Rank findings

Return only the highest-value findings first.

Prefer:

- 3–8 strong findings

instead of:

- 50 generic micro-optimizations.

## Phase 4 — Patch

If asked to modify code:

- patch the highest-confidence bottleneck first,
- keep changes localized,
- add comments only when needed,
- avoid speculative rewrites.

## Phase 5 — Verify

Provide:

- benchmark command/procedure
- profiler counters to compare
- expected direction of change
- possible regressions

---

# Output Template

Use this structure for a full audit.

```markdown
# Godot Performance Audit

## Target

- Godot:
- Renderer:
- Platform:
- Resolution:
- FPS target:
- Frame budget:

## Current Bottleneck

Classification:

Evidence:

## Highest-Priority Findings

### 1. [HIGH] Finding title

Confidence:

Evidence:

Impact:

Recommendation:

Tradeoffs:

Validation:

### 2. ...

## Secondary Findings

...

## Metrics to Capture Next

...

## Recommended Optimization Order

1.
2.
3.

## Expected Result

...
```

---

# Quick Triage Mode

If the user provides only profiler values, respond with a short bottleneck diagnosis.

Example input:

```text
FPS: 52
CPU: 8 ms
GPU: 18 ms
render thread: 4 ms
draw calls: 2900
```

Correct interpretation:

- GPU is the primary bottleneck.
- 2900 draw calls are not the first optimization target.
- investigate shadows, resolution, shaders, post-processing, transparency, and overdraw first.

Example:

```text
CPU: 18 ms
GPU: 7 ms
render thread: 14 ms
draw calls: 2600
```

Correct interpretation:

- CPU rendering is likely the primary bottleneck.
- draw-call/material/surface reduction is high priority.

---

# Final Rule

Performance advice must answer this question:

**What measured frame-time cost is this optimization expected to reduce?**

If that cannot be answered, classify the recommendation as speculative and lower its priority.
