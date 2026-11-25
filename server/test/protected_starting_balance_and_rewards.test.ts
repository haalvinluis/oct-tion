import { expect } from 'chai';
import { ProfileManager, PROTECTED_STARTING_BALANCE, DEFAULT_MATCH_ECONOMY } from '../src/database/profile_manager';
import { AuthManager } from '../src/database/auth_manager';

describe('PowerBid — Protected 500-Coin Starting Balance & Match Rewards Economy Tests', () => {
  let pm: ProfileManager;
  let auth: AuthManager;

  beforeEach(() => {
    pm = ProfileManager.getInstance();
    auth = AuthManager.getInstance();
  });

  // Case 1: New account starts with 500 coins.
  it('1. New account starts with exactly 500 coins', async () => {
    const profile = pm.getOrCreateProfile('new_player_test_1', 'NewPlayerOne');
    expect(profile.coinBalance).to.equal(500);

    const dto = pm.getProfileDTO('new_player_test_1');
    expect(dto.coinBalance).to.equal(500);

    // Also verify registration via AuthManager yields 500 starting coins
    const reg = await auth.registerAccount(
      `fresh_user_${Date.now()}@example.com`,
      'SecurePass123',
      `FreshPlayer_${Date.now().toString().slice(-4)}`
    );
    expect(reg.profile.coinBalance).to.equal(500);
    expect(pm.getProfileDTO(reg.profile.id).coinBalance).to.equal(500);
  });

  // Case 2: Player with 500 loses a match and remains at 500.
  it('2. Player with 500 loses a match and remains at 500', async () => {
    const pWinner = pm.getOrCreateProfile('p_win_c2', 'WinnerC2');
    const pLoser = pm.getOrCreateProfile('p_lose_c2', 'LoserC2');

    pWinner.coinBalance = 500;
    pLoser.coinBalance = 500;

    const participants = [
      { playerId: 'p_win_c2', rank: 1, itemsWon: 3 },
      { playerId: 'p_lose_c2', rank: 2, itemsWon: 1, isLoser: true },
    ];

    const matchId = `match_c2_${Date.now()}`;
    const rewards = pm.awardMatchCoins(matchId, 'p_win_c2', participants);

    // Loser penalty (-50) cannot drop below 500 floor
    expect(rewards.get('p_lose_c2')?.amount).to.equal(0);
    expect(pLoser.coinBalance).to.equal(500);
    expect(pm.getProfileDTO('p_lose_c2').coinBalance).to.equal(500);
  });

  // Case 3: Player with 650 loses and cannot fall below 500.
  it('3. Player with 650 loses and cannot fall below 500 across repeated losses', async () => {
    const pWinner = pm.getOrCreateProfile('p_win_c3', 'WinnerC3');
    const pLoser = pm.getOrCreateProfile('p_lose_c3', 'LoserC3');

    pLoser.coinBalance = 650; // Earned 650 coins

    // Loss 1: 650 - 50 = 600
    const m1 = `match_c3_1_${Date.now()}`;
    const r1 = pm.awardMatchCoins(m1, 'p_win_c3', [
      { playerId: 'p_win_c3', rank: 1, itemsWon: 3 },
      { playerId: 'p_lose_c3', rank: 2, itemsWon: 1, isLoser: true },
    ]);
    expect(r1.get('p_lose_c3')?.amount).to.equal(-50);
    expect(pLoser.coinBalance).to.equal(600);

    // Loss 2: 600 - 50 = 550
    const m2 = `match_c3_2_${Date.now()}`;
    const r2 = pm.awardMatchCoins(m2, 'p_win_c3', [
      { playerId: 'p_win_c3', rank: 1, itemsWon: 3 },
      { playerId: 'p_lose_c3', rank: 2, itemsWon: 1, isLoser: true },
    ]);
    expect(r2.get('p_lose_c3')?.amount).to.equal(-50);
    expect(pLoser.coinBalance).to.equal(550);

    // Loss 3: 550 - 50 = 500
    const m3 = `match_c3_3_${Date.now()}`;
    const r3 = pm.awardMatchCoins(m3, 'p_win_c3', [
      { playerId: 'p_win_c3', rank: 1, itemsWon: 3 },
      { playerId: 'p_lose_c3', rank: 2, itemsWon: 1, isLoser: true },
    ]);
    expect(r3.get('p_lose_c3')?.amount).to.equal(-50);
    expect(pLoser.coinBalance).to.equal(500);

    // Loss 4: At 500, loss penalty is clamped by the 500-coin protected floor!
    const m4 = `match_c3_4_${Date.now()}`;
    const r4 = pm.awardMatchCoins(m4, 'p_win_c3', [
      { playerId: 'p_win_c3', rank: 1, itemsWon: 3 },
      { playerId: 'p_lose_c3', rank: 2, itemsWon: 1, isLoser: true },
    ]);
    expect(r4.get('p_lose_c3')?.amount).to.equal(0);
    expect(pLoser.coinBalance).to.equal(500); // Strictly protected at 500!
  });

  // Case 4: Winner with 500 receives 150 and reaches 650.
  it('4. Winner with 500 receives 150 and reaches 650', async () => {
    const pWinner = pm.getOrCreateProfile('p_win_c4', 'WinnerC4');
    const pOpponent = pm.getOrCreateProfile('p_opp_c4', 'OpponentC4');

    pWinner.coinBalance = 500;
    pOpponent.coinBalance = 500;

    const participants = [
      { playerId: 'p_win_c4', rank: 1, itemsWon: 3 },
      { playerId: 'p_opp_c4', rank: 2, itemsWon: 1 },
    ];

    const matchId = `match_c4_${Date.now()}`;
    const rewards = pm.awardMatchCoins(matchId, 'p_win_c4', participants);

    expect(rewards.get('p_win_c4')?.amount).to.equal(150);
    expect(rewards.get('p_win_c4')?.reason).to.equal('MATCH_WIN_REWARD');
    expect(pWinner.coinBalance).to.equal(650);
    expect(pm.getProfileDTO('p_win_c4').coinBalance).to.equal(650);
  });

  // Case 5: Runner-up with 500 receives 75 and reaches 575.
  it('5. Runner-up with 500 receives 75 and reaches 575', async () => {
    const pWinner = pm.getOrCreateProfile('p_win_c5', 'WinnerC5');
    const pRunnerUp = pm.getOrCreateProfile('p_runner_c5', 'RunnerUpC5');
    const pThird = pm.getOrCreateProfile('p_third_c5', 'ThirdPlaceC5');

    pWinner.coinBalance = 500;
    pRunnerUp.coinBalance = 500;
    pThird.coinBalance = 500;

    const participants = [
      { playerId: 'p_win_c5', rank: 1, itemsWon: 3 },
      { playerId: 'p_runner_c5', rank: 2, itemsWon: 2 },
      { playerId: 'p_third_c5', rank: 3, itemsWon: 1 },
    ];

    const matchId = `match_c5_${Date.now()}`;
    const rewards = pm.awardMatchCoins(matchId, 'p_win_c5', participants);

    expect(rewards.get('p_runner_c5')?.amount).to.equal(75);
    expect(rewards.get('p_runner_c5')?.reason).to.equal('MATCH_RUNNER_UP_REWARD');
    expect(pRunnerUp.coinBalance).to.equal(575);
    expect(pm.getProfileDTO('p_runner_c5').coinBalance).to.equal(575);
  });

  // Case 6: Eligible participant with 500 receives 25 and reaches 525.
  it('6. Eligible participant with 500 receives 25 and reaches 525', async () => {
    const p1 = pm.getOrCreateProfile('p_1_c6', 'Player1C6');
    const p2 = pm.getOrCreateProfile('p_2_c6', 'Player2C6');
    const p3 = pm.getOrCreateProfile('p_3_c6', 'Player3C6');
    const p4 = pm.getOrCreateProfile('p_4_c6', 'Player4C6');

    p1.coinBalance = 500;
    p2.coinBalance = 500;
    p3.coinBalance = 500;
    p4.coinBalance = 500;

    const participants = [
      { playerId: 'p_1_c6', rank: 1, itemsWon: 3 }, // Winner (+150)
      { playerId: 'p_2_c6', rank: 2, itemsWon: 2 }, // Runner-up (+75)
      { playerId: 'p_3_c6', rank: 3, itemsWon: 1 }, // Eligible Participant (+25)
      { playerId: 'p_4_c6', rank: 4, itemsWon: 0 }, // Loser (clamped to 500)
    ];

    const matchId = `match_c6_${Date.now()}`;
    const rewards = pm.awardMatchCoins(matchId, 'p_1_c6', participants);

    expect(rewards.get('p_3_c6')?.amount).to.equal(25);
    expect(rewards.get('p_3_c6')?.reason).to.equal('MATCH_COMPLETION_REWARD');
    expect(p3.coinBalance).to.equal(525);
    expect(pm.getProfileDTO('p_3_c6').coinBalance).to.equal(525);
  });

  // Case 7: Repeated settlement cannot duplicate rewards.
  it('7. Repeated settlement cannot duplicate rewards (Idempotency guarantee)', async () => {
    const pWinner = pm.getOrCreateProfile('p_win_c7', 'WinnerC7');
    const pRunnerUp = pm.getOrCreateProfile('p_run_c7', 'RunnerUpC7');

    pWinner.coinBalance = 500;
    pRunnerUp.coinBalance = 500;

    const participants = [
      { playerId: 'p_win_c7', rank: 1, itemsWon: 3 },
      { playerId: 'p_run_c7', rank: 2, itemsWon: 1, isRunnerUp: true },
    ];

    const matchId = `match_c7_idem_${Date.now()}`;

    // 1st Settlement Call
    const r1 = pm.awardMatchCoins(matchId, 'p_win_c7', participants);
    expect(r1.get('p_win_c7')?.amount).to.equal(150);
    expect(pWinner.coinBalance).to.equal(650);

    // 2nd Settlement Call (Same matchId)
    const r2 = pm.awardMatchCoins(matchId, 'p_win_c7', participants);
    expect(r2.size).to.equal(0);
    expect(pWinner.coinBalance).to.equal(650); // Balance unchanged!

    // 3rd Settlement Call
    const r3 = pm.awardMatchCoins(matchId, 'p_win_c7', participants);
    expect(r3.size).to.equal(0);
    expect(pWinner.coinBalance).to.equal(650); // Still 650!
  });

  // Case 8: Two accounts retain separate, correct balances.
  it('8. Two accounts retain separate, correct balances', async () => {
    const pAlpha = pm.getOrCreateProfile('p_alpha_c8', 'AlphaPlayer');
    const pBeta = pm.getOrCreateProfile('p_beta_c8', 'BetaPlayer');

    pAlpha.coinBalance = 500;
    pBeta.coinBalance = 500;

    const participants = [
      { playerId: 'p_alpha_c8', rank: 1, itemsWon: 3 },
      { playerId: 'p_beta_c8', rank: 2, itemsWon: 2, isRunnerUp: true },
    ];

    const matchId = `match_c8_${Date.now()}`;
    pm.awardMatchCoins(matchId, 'p_alpha_c8', participants);

    // Alpha won: 500 + 150 = 650
    expect(pAlpha.coinBalance).to.equal(650);
    expect(pm.getProfileDTO('p_alpha_c8').coinBalance).to.equal(650);

    // Beta was runner up: 500 + 75 = 575
    expect(pBeta.coinBalance).to.equal(575);
    expect(pm.getProfileDTO('p_beta_c8').coinBalance).to.equal(575);

    // Independent checks
    expect(pAlpha.coinBalance).to.not.equal(pBeta.coinBalance);
  });

  // Case 9: Existing accounts keep their earned coins during updates.
  it('9. Existing accounts keep their earned coins during updates and operations', async () => {
    const pVeteran = pm.getOrCreateProfile('p_vet_c9', 'VeteranPlayer');
    pVeteran.coinBalance = 1450; // Earned through many victories

    // Operation 1: Profile DTO fetching preserves balance
    const dto = pm.getProfileDTO('p_vet_c9');
    expect(dto.coinBalance).to.equal(1450);

    // Operation 2: Username update preserves balance
    const updateRes = pm.updateUsername('p_vet_c9', 'VeteranPro99');
    expect(updateRes.success).to.be.true;
    expect(pVeteran.coinBalance).to.equal(1450);

    // Operation 3: Win in a match increases earned coins
    const matchWinId = `match_c9_win_${Date.now()}`;
    pm.awardMatchCoins(matchWinId, 'p_vet_c9', [
      { playerId: 'p_vet_c9', rank: 1, itemsWon: 3 },
      { playerId: 'p_other_c9', rank: 2, itemsWon: 1 },
    ]);
    expect(pVeteran.coinBalance).to.equal(1600); // 1450 + 150 = 1600

    // Operation 4: Loss in a match deducts from earned balance without dropping below 500
    const matchLossId = `match_c9_loss_${Date.now()}`;
    pm.awardMatchCoins(matchLossId, 'p_other_c9', [
      { playerId: 'p_other_c9', rank: 1, itemsWon: 3 },
      { playerId: 'p_vet_c9', rank: 2, itemsWon: 1, isLoser: true },
    ]);
    expect(pVeteran.coinBalance).to.equal(1550); // 1600 - 50 = 1550 (never reset to 500!)
  });
});
