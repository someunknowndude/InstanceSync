
# InstanceSync

Universal client-to-client instance replication library using [BugSocket](https://github.com/4DBug/Socket)


## Testing game

#### An uncopylocked game containing the library and example scripts (see the examples folder in the repo) can be found [here](https://www.roblox.com/games/113331189278524/bugsocket-instance-replication)



## API Reference

#### Load the library

```lua
  local sInstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/someunknowndude/InstanceSync/refs/heads/main/InstanceSync.lua"))()
```

#### Create synced Instance

```lua
  <Instance> sInstance.new(<string> className, <Instance> Parent?)
```


#### Create synced instance from existing Instance

```lua
  <Instance> sInstance.fromExisting(<Instance> originalInstance)
```


#### Create synced clone of Instance

```lua
  <Instance> sInstance.clone(<Instance> originalInstance)
```


#### Set property on any serversided or replicated Instance

```lua
  <void> sInstance.set(<Instance> targetInstance, <string> propertyName, <any> value)
```


#### Fully destroy an Instance

```lua
  <void> sInstance.destroy(<Instance> targetInstance)
```


#### Break joints of a BasePart or Model

```lua
  <void> sInstance.breakJoints(<BasePart|Model>)
```


#### Claim serversided Instance to automatically replicate its property changes and `:Destroy()` calls

```lua
  <void> sInstance.claim(<Instance> serversidedInstance)
```


#### Claim entire LocalPlayer Character, useful for converting SB/require scripts

```lua
  <void> sInstance.claimCharacter()
```

### Global variables

#### Access the library anywhere after loading it once

```lua
  local sInstance = _G.InstanceSync
```


#### Increase the wait time before `.new()`, `.fromExisting()` and `.clone()` return their created Instances to help against lag

```lua
  _G.syncBaseWaitTime = 0.5 -- defaults to 0.2
```
*The formula for the total wait time is*
```lua 
  _G.syncBaseWaitTime + (NetworkPing * 2)
```
*where NetworkPing is the current ping in ms*


#### Dictionary including all created, received and claimed Instances

```lua
  _G.syncedInstances -- ["UniqueID"] = Instance
```


#### Dictionary including created and claimed BaseParts used for CFrame replication

```lua
  _G.syncedBaseParts -- ["UniqueID"] = BasePart
```
