// Simple round-robin generator (circle method)
export function generateRoundRobin(teamIds: number[]) {
  const teams = [...teamIds];
  const odd = teams.length % 2 === 1;
  if (odd) teams.push(-1); // bye

  const n = teams.length;
  const rounds: { home: number; away: number }[][] = [];

  for (let round = 0; round < n - 1; round++) {
    const pairs: { home: number; away: number }[] = [];
    for (let i = 0; i < n / 2; i++) {
      const t1 = teams[i];
      const t2 = teams[n - 1 - i];
      if (t1 === -1 || t2 === -1) continue; // skip byes
      // Alternate home/away to balance
      if (round % 2 === 0) pairs.push({ home: t1, away: t2 });
      else pairs.push({ home: t2, away: t1 });
    }

    rounds.push(pairs);

    // rotate (except first)
    teams.splice(1, 0, teams.pop() as number);
  }

  return rounds;
}
