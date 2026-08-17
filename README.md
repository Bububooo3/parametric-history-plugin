# parametric-history-plugin
fusion 360 timeline system but for Roblox Studio

[Fusion 360 Design History Mechanic](https://www.youtube.com/watch?v=Og0N380_A0U)

<br>

Parametric history is a mechanic that allows developers to turn back time, edit parameters on objects, and then go back into the future and see those changes take effect.

For example, I could scroll back to time point B and put a hole in a cube, and when I scroll forward to the latest point, all of the operations (extrude, rotate, clone, etc.) I had run on that cube between time point B and the latest point will take effect as if there had always been a hole there. I find it a useful and interesting mechanic, so I wanted to try and implement it in Roblox Studio or at least in Luau.

Regarding the code, MapStore enables me to get the history of one object, while LinkedStore is for looking at the timeline as a whole. The biggest design flaw was deciding to use clock time when I started instead of a counter.

<hr>

### (New plan)

- Change from using `os.time()` to using an incremented entry `id` and an `offset` value in reference to location in the buffer
    
    - `tracked[UID][id]` replaces `tracked[UID][timestamp]`

    - Incrementing id means `LinkedStore` is linear now and I don't need to run `sortByTimestamps()` every time which was dumb

    - Also insertion becomes way easier

- Add a HistoryController module etc.

    - LinkedStore and MapStore are doing more work than their names imply. The buffer-writing should be its own thing.

    - It makes sense to have a central controller that the main script can interface with.

    - plugin.lua is doing the tracking, which isn't great. Also an organization thing.

    - ```lua
        -- (What I'm thinking. Obv not functional code)

        export type ObjectHistory = {
            -- track captures of individual objects in a map like in the current MapStore. {obj: {[id] = {offset, operation}}}. Storing operation bc I need it for recomputing all relevant captures between a change in the past and the next time that property is changed instead of overwriting or doing a bunch of looping thru the buffer since everywhere else captures are stored as chunks.
            "addEntry", "getLatestFromObjBefore", "killObj", "removeEntry", "clear"
        }

        export type Storage = {
            -- store capture data in a buffer like in the current MapStore
            "readFromOffset", "writeFromData", "shift", "clear"
        }

        export type Timeline = {
            -- a basic double linkedlist of nodes but as its own data structure. The nodes only have UID and id like the current LinkedStore.

        }

        export type Tracker = {
            -- handles connections, so it would also handle UID and triggering captures like the current plugin.lua does. Maybe it should be ECS, but idk. Might try that after the initial project works.

        }

        export type TVA = {
            -- name inspired from Loki. Does what setTime(), snipPast(), snipFuture(), etc. were supposed to. Handles all the 3D-workspace interactions with the plugin like implementing timeline position changes. Should go from shortest distance tho whether it's starting from 0 or current spot in time. Does operation + prev = next whenever a change in the past happens so it's kind of like Markov Chains.

        }

        export type HistoryController = {
            -- meant to interface directly w/ plugin.lua (which should handle UI stuff mainly) and combine the modules into callable and labeled processes like an untraditional undo/redo, etc.
        }
        ```
