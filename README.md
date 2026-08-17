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



- 