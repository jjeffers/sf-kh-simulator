PRD: GOG Galaxy User Identification Integration
Project: SFKH Simulator (Godot Engine)
Version: 1.0
Status: Draft / Engineering Review

1. Executive Summary
The goal is to implement the GOG Galaxy SDK into the SFKH Simulator to uniquely identify players. This will facilitate "Cloud Saves," "Achievements," and "Multiplayer Identity" while ensuring the game remains compliant with GOG’s distribution requirements.

2. User Stories
As a Player: I want my GOG profile to be recognized automatically so my progress is tied to my account.
As a Developer: I want to retrieve a unique, persistent GOG_ID to manage user data and prevent save-file spoofing.
As a User: I want to be able to play offline if I don't have an internet connection, without the game crashing.

3. Functional Requirements
3.1 Authentication Flow
Initialize SDK: On startup, the game must initialize the Galaxy SDK.
Silent Login: The system should attempt a "Silent Login" using the Galaxy Client credentials.
Failure Handling: If the Galaxy Client is not running, the game should default to a "Local Guest" profile.

3.2 Data Retrieval
The system must be able to fetch:
Galaxy ID: A unique 64-bit integer.
Persona Name: The user’s display name (e.g., "SpaceCaptain99").
Authentication Token: For secure backend verification (if applicable).

3.3 Godot Integration (Technical)
Middleware: Since Godot doesn't support GOG out-of-the-box, use a wrapper like GodotGalaxy or a custom GDExtension.
Signals: The wrapper must emit Godot signals (e.g., on_gog_auth_success, on_gog_auth_failure).

4. Technical Architecture & Logic
The logic flow follows a standard asynchronous handshake:
StepActionDescription
1InitCall Galaxy.api.init(client_id, client_secret).
2ListenerSet up a listener for AuthListener.
3SignInCall Galaxy.api.user.sign_in().
4CallbackProcess OnAuthSuccess or OnAuthFailure.
5RetrievalIf success, call Galaxy.api.user.get_galaxy_id().
5. Success Criteria
The game successfully displays the GOG Username on the main menu.
The game logs a valid 64-bit GalaxyID to the console/debug log.
The game does not hang if the GOG Galaxy Client is closed during initialization.

6. Security & Privacy
PII: Do not store the user's email or real name; only use the GalaxyID for data mapping.
Offline Mode: Ensure the GalaxyID is cached locally (encrypted) to allow for offline play after the initial verification.