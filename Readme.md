BLOXY KARTS

Arcade kart racing game inspired by the blocky visual style of Roblox.

Project

First playable prototype of BLOXY KARTS.

Initial goals

- Third-person arcade kart driving.
- Blocky Jungle as the first race track.
- Up to 8 players.
- 3-lap races.
- Drifting and boost mechanics.
- Kart collisions.

Development

This project is being developed with Roblox Studio, Visual Studio Code, Git and GitHub.

Prototype: kart driving

The first playable prototype builds a blocky kart and a simple test course at runtime. Each player receives an individual server-created kart. The server validates driver input and assigns network ownership to the seated driver; that client simulates the kart's physical assembly while the server observes its movement. The prototype intentionally does not include drifting, boost, weapons, coins, shops, matchmaking, or a lobby.

Controls

- W / Up: accelerate.
- S / Down: brake while moving forward, then reverse.
- A / Left and D / Right: steer.
- Space: brake.
- E: enter the kart when standing next to it.

Testing in Roblox Studio

1. Install the project tools with Rokit (`rokit install`) so the pinned Rojo 7.7.1 version is used.
2. Open the project in Roblox Studio and connect Rojo from the project directory with `rojo serve`.
3. Synchronize `default.project.json` into the Studio place.
4. Use Test > Start with at least one player. The server creates the test course and a kart for each player.
5. Drive on the asphalt pad and test the boundary walls and block obstacles.

The server scripts and shared configuration live under `src/ServerScriptService` and `src/ReplicatedStorage`; the local camera, keyboard controls, and physical simulation live under `src/StarterPlayer` (mapped to `StarterPlayerScripts` by Rojo).
