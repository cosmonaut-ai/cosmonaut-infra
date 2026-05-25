# Project Description

Cosmonaut AI is an interactive storytelling platform where users create and explore branching, text-based adventures generated with large language models.

Each story begins with a user-provided world prompt and continues through a sequence of choices. The story graph is represented as worlds and story nodes: each node contains narrative text, available choices, parent/child relationships, and metadata used for traversal, sharing, and regeneration.

The core product requirement is narrative consistency. Facts established in a world should remain coherent as users move through branches, backtrack, and explore alternative paths. The infrastructure supports this through persistent story state, vector-memory services, authenticated APIs, media storage, and deployment boundaries between frontend, API, streaming, and worker components.

The current platform supports web and Android clients, authenticated user accounts, subscription billing, generated narration, public sharing, and static content delivery.
