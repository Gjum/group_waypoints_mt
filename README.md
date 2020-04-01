# Group Waypoints

Create and share waypoints in PlayerManager groups.

## Functionality

- playermanager groups contain waypoints
- group members can see all waypoints in that group
- players can edit/delete their own waypoints in any group they're a member of
  - players cannot edit/delete waypoints in groups they are no longer a member of
- a group's admins can edit/delete any waypoints in that group
- players can turn on/off visibility of all waypoints in a group for themselves
- players can turn on/off visibility of individual waypoints for themselves, overriding their configured group visibility
- deleting/renaming groups and updating group permissions work as expected

## Commands

- `/wp new <group> [name]` - Instantly create a waypoint at the current position, in group `group`, with name `name` (default: x, y, z coordinates).
- `/wp manage [group]` - Open a GUI to manage all waypoints in group `group` (default: all groups).
