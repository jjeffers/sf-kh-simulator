# Second Sathar War (Campaign)

## High-Level Goals

The "Second Sathar War" is a campaign-level game mode where the strategic movement of fleets dictates the engagements fought in the tactical space battle system.

*   **Sathar Objective:** Invade the star systems and destroy all UPF stations.
*   **UPF Objective:** Defend the star systems, protect the stations, and eliminate the invading Sathar fleets.

## Game Startup Screen

When starting a new campaign of the "Second Sathar War", the player will be presented with the following options:

**Start Campaign** - Begins the Second Sathar War campaign as host.
**Load Campaign** - Loads a saved campaign of the Second Sathar War.
**Join Campaign** - Joins a campaign of the Second Sathar War hosted by another player.
**Start Scenario** - Begins a specific scenario of the Second Sathar War campaign.
**Quit** - Exits the game.

**Start Campaign** - Hosts a new campaign of the Second Sathar War.
    - show the ip and port for the host, which can be changed if desired
    - default is localhost port 7000

**Join Campaign** - Joins an existing campaign of the Second Sathar War.
    - Remembers the last ip and port used to join a campaign
    - default is localhost port 7000
## Campaign Game Flow

The campaign operates in a loop consisting of a Strategic Phase where fleets are moved on a star map, and a Tactical Phase where encounters are resolved using the core space battle mechanics.

### 1a. Lobby

This screen shows the current campaign state, including the current turn number, the current date, and the current factions. Also displays the victory conditions for each faction.

Players who join the campaign may select which side they join. The host may launch the campaign when all players have joined and selected their factions with the "Launch Campaign" button.

**Select Faction:** Choose to play as the **Sathar** or the **United Planetary Federation (UPF)**. Players can join either side, and at least 1 player must join each side.

### 1b. Campaign Parameters - SKIP FOR NOW - TO BE ADDED LATER

**UPF** 

Once the campaign parameters are set, the game transitions to the Strategic Phase.

### 2. Strategic Phase (Frontier Star Map)

* **UI Layout**
    - The UI is divided into two main sections: the star map and the fleet management panel.
    - The star map is displayed in the center of the screen and shows the star systems and travel routes.
    - The fleet management panel is displayed on the right side of the screen and shows the fleets and their compositions.
    - The top of the screen displays the current turn number and the current date ("Day 1", "Day 2", etc).

    **Suggested UI Flow**
    Fleet Interaction (On Map)
        Deck Expansion: Clicking a stacked "deck" of fleet icons expands them into a radial or linear fan. The user then clicks the specific fleet they wish to manage.

        Active Selection: Clicking a fleet on the map automatically selects it in the Fleet List (Top Right) and populates the Composition (Bottom Right).

    Managing Ships & Transfers
    Transfer:

        Select the Source Fleet from the Fleet List or Map.

        In the Composition Panel, use the mouse (or spacebar) to "Tag" specific ships.

        Click a Destination Fleet on the map or list. A "Transfer" button appears; clicking it moves tagged ships to the target.

    Create New Fleet:

        Tag ships in the Composition Panel.

        Click a "New Fleet" button at the bottom of the panel.

        This prompts for a name and spawns a new fleet icon at the current system coordinates.

    Merge:

        Drag a fleet icon on the map and drop it onto another fleet icon.

        A confirmation prompt appears: "Merge [Fleet A] into [Fleet B]?"

    Renaming
        Quick Rename: Double-clicking the fleet name in the Fleet List or Composition Header opens a text input field to rename the unit (e.g., changing "Task Force Prenglar" to "Home Defense Force").

    Moving Between Systems
        1. Fleet Selection & Destination
            Select Fleet: Click the fleet icon on the map or use the TAB key to highlight the fleet in the Fleet List panel.

            Expand Decks: If multiple fleets are at the same system, click the "deck" icon to expand and select the specific unit (e.g., Strike Force NOVA).

            Set Destination: Click the target star system (e.g., moving from Prenglar to Cassidine).

    2. Route Verification & Transit Calculation
    Identify Navigation Lines: The UI should highlight the valid transit lanes connecting the origin to the destination.

    
    Determine Travel Time:

        Military Movement: All movement between sysyems takes 5 days.

        Total Duration: The UI should display the estimated arrival day (e.g., "Arriving at Cassidine on Day 5").

    3. Execution & Logging
        Confirm Movement: Click "Execute Jump" to lock in the coordinates for the current turn.

        Automated Logging: The Event Log at the bottom of the screen will record the departure (e.g., "LOG: TF Cassidine has jumped for Prenglar. ETA: Day 04.").

        En Route Status: The fleet icon will move along the transit line, centered on the current "Transit Box" corresponding to the elapsed days.
        
*   **Strategic Turn**
    - Each turn represents a day.
    - Both sides issue orders and then "End Turn" - all actions are executed simultaneously.

*   **Map Overview:** The campaign takes place on a map of star systems interconnected by travel routes. The map data is driven by a data file that is loaded at the start of the campaign. The map is displayed in a 2D view with the star systems as nodes and the travel routes as edges.
    - Coordinate Grid: Labeled $X$ (0 to 45) and $Y$ (0 to 55) based on your corrected map coordinates.
    - Map data is loaded from Data/campaign_map.json
    - The map is displayed in a 2D view with the star systems as nodes and the travel routes as edges.
    - Space stations are shown on the map as icons at the location of the star system.
    - Sathar and UPF fleets are shown on the map as icons at the location of the star system.
    - Sathar Start Circles should be a deep red color, and act effectively as Sathar-only systems.
    - UPF systems should be an empty circle with a blue border.


* **Fleets**
    **Fleet Management** 
    - Fleets are composed of ships. 
    - Ships can be transferred between fleets in the same system.
    **Fleet Movement:** Players (or AI) move their fleets between systems.
    - Fleets move along the navigation routes defined in Data/campaign_map.json
    - Fleets can only move between systems that are connected by a navigation route.
    - Only Sathar fleets may move to/from Sathar Start Circles to the connected systems.

*   **Fleet Composition:** Fleets are composed of ships. Some sytems have stations - armed and/or fortified.

    - **Sathar Fleets**: 
        - The Sathar starts with 3 fleets.
        - The fleets are composed of: 25 Fighters, 8 Frigates, 15 Destroyers, 7 Light Cruisers, 8 Heavy Cruisers,4 Assault Carriers
    - Ships will be randomly assigned to fleets with following constraints:
        - Each fleet must have at least 1 Assault Carrier
        - Each assault carrier wil have no more than 8 fighters
        - Each fleet will be asssigned to start in a different Sathar Start Circle
        
    **UPF Fleets**:
        Task Force Cassidine (at Cassidine)
            6 Fighters
            3 Assault Scouts
            2 Frigates
            1 Light Cruiser
            1 Heavy Cruiser
            1 Battleship
            1 Assault Carrier
            1 Minelayer

        Task Force Prenglar (at Prenglar)
            1 Minelayer
            5 Assault Scouts
            3 Frigates
            2 Destroyers
            3 Light Cruisers
            1 Battleship
            1 Assault Carrier

        Strike Force NOVA
            6 Fighters
            3 Assault Scouts
            2 Frigates
            1 Destroyer
            2 Light Cruisers
            1 Battleship
            1 Assault Carrier

        Non-Attached Ships
            4 Fighters
            3 Assault Scouts
            1 Minelayer
            2 Destroyers
            2 Light Cruisers

        Planetary Militia Forces
            Militia ships begin the game based at a station orbiting their respective planets.
            Gollywog (White Light): 3 Assault Scouts, 1 Frigate
            Hentz (Araks): 3 Assault Scouts, 1 Frigate
            Ken’zah Kit (K’aken Kar): 2 Assault Scouts
            Outer Reach (Dramune): 2 Assault Scouts, 2 Frigates
            Terledrom (Fromeltar): 3 Assault Scouts, 1 Frigate
            Hargut (Gruna Garu): 2 Assault Scouts
            Inner Reach (Dramune): 3 Assault Scouts, 1 Frigate, 1 Destroyer
            Minotaur (Theseus): 4 Assault Scouts, 1 Frigate, 1 Destroyer
            Pale (Truane’s Star): 3 Assault Scouts, 1 Frigate
            Zik-kit (Kizk’-Kar): 2 Assault Scouts

            Planetary Defensive Stations
                Fortified Stations
                    Minotaur (Theseus)
                    Ken’zah Kit (K’aken Kar)
                    Hentz (Araks)
                    Gran Quivera (Prenglar)

                Armed Stations
                    Kawdl-Kit (K’tsa-Kar)
                    Kikit (Kizk’-Kar)
                    Groth (Fromeltar)
                    New Pale (Truane’s Star)
                    Inner Reach (Dramune)
                    Outer Reach (Dramune)
                    Rupert’s Hole (Cassidine)
                    Triad (Cassidine)
                    Hargut (Gruna Garu)
                    Lossend (Timeon)
        - **UPF Fleets constraints**
            - Task force NOVA starts at a random location:
                Roll (1d10) 
                1–3 Gran Quivera (Prenglar)
                4 Pale (Truane's Star)
                5 Inner Reach (Dramune)
                6 Terledrom (Fromeltar)
                7 Zik-Kit (Kizk'-Kar)
                8 Kenzah-kit (K'aken Kar)
                9 Gollywog (White Light)
                0 Kawdl-Kit (K'tsa-Kar)
            - Non-attached ships are randomly distributed among the UPF fleets.

*   **Detection & Intelligence:** Fleets may have limited visibility. Scouting and detection mechanics determine what information players have about enemy fleet locations and compositions. 
    - Each side has full visibility in systems where the have a fleet or station, otherwise they have no visibility and cannot see or detect enemy ships. 
    
*   **Encounters:** When a Sathar fleet and a UPF fleet occupy the same location (or when the Sathar arrive at a UPF station), an encounter is triggered.

### 3. Tactical Phase (Space Battles)

*   **Combat Resolution:** Encounters triggered in the Strategic Phase are fought out using the existing tactical space battle system.
*   **Deployment & Setup:** The forces involved are directly determined by the fleets that engaged on the strategic map. The tactical scenario is generated based on the location (e.g., fighting near a planet, defending a starbase, or deep space).
    - planets are always placed at the center of the map
    - stations are always placed in orbit around planets
    - defenders may deploy anywhere within 34 hexes, any facing or speed
    - attackers must deploy 34 hexes from the center, any facing or speed
*  **Retreat**
    - Retreating forces must be outside of enemy weapon range and a button will appear during movement planning labbelled "Withdraw". Clicking this will remove the ship from the map and be counted as reteated.
    - Militia ships must make 1 attack before retreating from combat in their home system.
    - 
*   **Battle Aftermath:**
    *   Destroyed ships are removed from the campaign.
    *   Damaged or crippled ships carry their status back to the strategic map.
    *   Retreating forces must withdraw to an adjacent, safe system.


### 4. Campaign Management & Logistics

*   **Repairs:** No repairs outside of combat
*   **Ordnance & Fighters:** Expenditure of seekers, mines, and fighters must be tracked. Fleets may need to return to bases or carriers to re-arm.
*   **Reinforcements:** No reinforcements are allowed during the campaign. No ships may be built or repaired during the campaign. (TBD added later)

## Victory Conditions

*   **Sathar Victory:** Successfully destroy 12 stations and all 4 fortresses
*   **UPF Victory:** Prevent the Sathar from destroying 12 stations and all 4 fortresses.
