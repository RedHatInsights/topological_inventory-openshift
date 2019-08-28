# Secrets directory

This directory is intended for multi-source collector mode (started with `config` argument).

You have to create `credentials` file for each source defined in `config/<your file>.yml`

See [credentials.example](credentials.example)

On Insights platform, this file is mounted by topological-inventory-orchestrator as Secret.
 