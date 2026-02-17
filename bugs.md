# Bug Tracker

## 🚨 Critical / High Priority
- [x] [UI] When multiple ships are stacked, clicking on the stack should prioritize targeting an enemy ship if the current ship is in attack planning mode, rather than selecting the friendly ship in the stack. (Fixed 2026-02-17)

## 🐛 Backlog
- [ ] 

## 🔍 Needs Investigation
- [ ] 

## ✅ Fixed
- [x] Fixed speed 0 facing constraint bug: Moving 1 hex after free rotation resulted in invalid turning constraints due to incorrect entry facing calculation. (2026-02-16)
- [x] Fixed Infinite Ammo Bug where ammo count of -1 was treated as insufficient ammo. (2026-02-17)
