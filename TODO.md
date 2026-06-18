# Admin System Development Roadmap

## Overview
This document outlines the development roadmap for the League Admin system. It provides a phased approach to building out core functionality with clear acceptance criteria and procedures for tracking progress.

## Current Status (Completed)

### Foundation Phase ✅
- **Express + TypeScript Scaffold**: Full Node.js/Express setup with TypeScript configuration
- **Prisma Schema**: Core data models defined (Players, Teams, Seasons, Matches, Registrations)
- **Authentication System**: Login/session management for admin access
- **Seasons CRUD**: Create, read, update, delete operations for seasons
- **Admin Index UI**: Dashboard landing page for admin panel

### Registrations Phase ✅
- **Public Registration Submission**: Players can submit registration data via public endpoint
- **Admin Registration List**: View and manage all submitted registrations in admin UI
- **JSON Import Endpoint**: API endpoint for bulk importing registration data
- **CSV→JSON Import UI**: Admin tool to convert CSV files to JSON format for bulk import

### Fixtures Phase ✅
- **Round-Robin Generator**: Algorithm to generate fixtures for league seasons
- **Fixtures Preview**: UI to preview generated fixtures before persisting
- **Fixtures Persist Endpoint**: API to save generated fixtures to database
- **Admin Fixtures UI**: Interface for managing season fixtures

### Documentation Phase ✅
- **README**: Project overview and architecture documentation
- **Setup Instructions**: Minimal run instructions for local development

---

## Upcoming Phases

### Phase 1: Match Results & Scoring
**Objective**: Enable admin to input match results and automatically calculate league standings

**Tasks**:
- [ ] Create Match Results input form in admin UI
- [ ] Add API endpoint for submitting match scores
- [ ] Implement points calculation logic (win=3, draw=1, loss=0)
- [ ] Create Standings view showing league table
- [ ] Add validation for duplicate/conflicting results

**Acceptance Criteria**:
- Admin can input match results for any fixture
- League table automatically updates with correct points and positioning
- Results cannot be entered for future matches
- Results cannot be duplicated

**Procedure**: 
1. Create branch `feature/match-results`
2. Implement form component in `src/views/admin/matches/`
3. Add endpoint in `src/api/matches.ts`
4. Mark completed when all acceptance criteria pass

---

### Phase 2: Team Management
**Objective**: Allow admin to create, edit, and manage league teams

**Tasks**:
- [ ] Create Team CRUD endpoints (POST, GET, PUT, DELETE)
- [ ] Build Team management UI with list view
- [ ] Add team profile editing form
- [ ] Link teams to seasons
- [ ] Implement team roster management

**Acceptance Criteria**:
- Admin can create teams with name, short code, logo URL
- Admin can edit team details
- Admin can delete teams (with cascade handling)
- Teams can be assigned to seasons
- Team logos display in UI

---

### Phase 3: Player Management
**Objective**: Admin interface for managing registered players

**Tasks**:
- [ ] Create Player management dashboard
- [ ] Build player detail view with stats
- [ ] Add player search/filter functionality
- [ ] Implement player status management (active/inactive/suspended)
- [ ] Create bulk player action tools

**Acceptance Criteria**:
- Admin can view all players with searchable table
- Admin can update player status
- Player statistics are visible
- Can filter by team, season, or status

---

### Phase 4: League Settings & Rules
**Objective**: Make league configuration flexible through admin settings

**Tasks**:
- [ ] Create Settings management page
- [ ] Add configurable rules (points per win/draw/loss)
- [ ] Implement match scheduling preferences
- [ ] Add league branding settings
- [ ] Create backup/restore functionality

**Acceptance Criteria**:
- League settings persist to database
- Rules changes apply to new calculations
- Settings are versioned for audit trail

---

### Phase 5: Reporting & Analytics
**Objective**: Provide insights into league performance and trends

**Tasks**:
- [ ] Create reports dashboard
- [ ] Build match statistics view
- [ ] Add player performance analytics
- [ ] Implement CSV export functionality
- [ ] Create season summary reports

**Acceptance Criteria**:
- Admin can view key league statistics
- Reports can be exported in CSV format
- Historical data is tracked

---

## How to Mark Tasks Complete

When completing a task in a phase:

1. **Update this document** by checking the checkbox:
   ```markdown
   - [x] Task name (completed)
   ```

2. **Create a pull request** with:
   - Title: `[Phase X] Feature name`
   - Reference this TODO.md in the PR description
   - Link related issues if applicable

3. **Merge the PR** once approved

4. **Update Phase status** once all tasks in a phase are complete:
   ```markdown
   ### Phase X: Name ✅
   ```

---

## Development Guidelines

- **Branching**: Use `feature/description` for new features, `bugfix/description` for bug fixes
- **Commits**: Write clear, descriptive commit messages
- **Testing**: Add tests for new endpoints and UI components
- **Database**: Run migrations before testing: `npx prisma migrate dev`
- **Code Review**: All PRs require review before merging

---

## Notes for Implementation

- Keep UI components reusable and consistent with existing admin design patterns
- Use Prisma ORM for all database operations
- Follow existing error handling patterns
- Document API endpoints with request/response examples
- Consider performance for large datasets (pagination, indexing)

---

**Last Updated**: June 18, 2026
