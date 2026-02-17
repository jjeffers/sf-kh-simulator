- [ ] 

## 🐛 Backlog
- [ ] 

## 🔍 Needs Investigation
- [ ] 

## ✅ Fixed
- [x] Fixed stack selection bug: Clicking on an enemy stack with a friendly ship selected now correctly targets the enemy if a weapon is active. (2026-02-16)
- [x] Fixed speed 0 facing constraint bug: Moving 1 hex after free rotation resulted in invalid turning constraints due to incorrect entry facing calculation. (2026-02-16)
- [x] Fixed Infinite Ammo Bug where ammo count of -1 was treated as insufficient ammo. (2026-02-17)
- [x] Fixed Stack Selection Visual Mismatch: Targeting now correctly selects the visually top-most ship in a stack (based on scene tree order) instead of the bottom ship. (2026-02-17)
