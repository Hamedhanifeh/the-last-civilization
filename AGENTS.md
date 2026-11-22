# The Last Civilization

- Work in the five steps in [the roadmap](docs/README.md). Agree on the current step with the user. Run the game and the relevant tests, deliver a signed Android APK, and record its version and the test results in that step's Markdown file before advancing.
- Keep the Android package name and local test signing identity consistent so each step's APK can update the previous one. Increase the Android version code for each delivery. Never commit a keystore or its password.
- Use the installed `graphify` skill throughout development. Start architecture and change-impact investigations with the current graph when it exists. Check graph findings against the source files. Refresh the graph after meaningful code or design changes and record one relevant query and its result in the current step's document.
- During the initial Godot work, check which `.gd`, `.tscn` and `project.godot` files actually appear in the graph. If the installed parser skips them, use source inspection and clearly identify the unsupported files in the step's analysis.
- Keep the game, its tests and its documentation in this repository. See [the Graphify workflow](docs/GRAPHIFY.md) for the graph's scope and outputs.
