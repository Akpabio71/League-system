# Next steps

This commit adds:
- Registration endpoints + import support (JSON rows) and admin UI (admin/registrations.html)
- Fixture generator service (round-robin) and endpoints + UI (admin/fixtures.html)

How CSV import works:
- The admin UI reads the CSV in the browser and POSTs rows as JSON to the backend import endpoint.
- CSVs should have a header row containing at least `teamName` (and optionally `club`).

What's left:
- Improve CSV parsing for quoted/complex CSVs or add server-side file upload parsing.
- Add unit tests and validation.
