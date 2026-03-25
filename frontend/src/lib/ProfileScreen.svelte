<script>
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  // Placeholder user profile payload; can be replaced with API data later.
  const profile = {
    name: 'Barangay Ops User',
    role: 'admin',
    email: 'ops@mapsumbong.local',
    barangay: 'Metro Manila Command',
    shift: '06:00 - 14:00',
    assignedIncidents: 12,
    resolvedToday: 7,
    memberSince: '2026-01-15',
  };

  const roleLabel = profile.role === 'admin' ? 'Administrator' : 'Standard User';
</script>

<section class="profile-wrap">
  <div class="profile-card">
    <div class="header">
      <button class="back-btn" aria-label="Back to dashboard" on:click={() => dispatch('back')}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <path d="m15 18-6-6 6-6"/>
        </svg>
        Back
      </button>
      <div class="title-wrap">
        <h2>Profile</h2>
        <p>Account and operations details</p>
      </div>
      <div class="role-pill" class:admin={profile.role === 'admin'}>{roleLabel}</div>
    </div>

    <div class="body">
      <div class="avatar-row">
        <div class="avatar">{profile.name.split(' ').map(s => s[0]).join('').slice(0, 2)}</div>
        <div>
          <div class="name">{profile.name}</div>
          <div class="muted">{profile.email}</div>
        </div>
      </div>

      <div class="grid">
        <article class="item">
          <div class="k">Role</div>
          <div class="v">{roleLabel}</div>
        </article>
        <article class="item">
          <div class="k">Barangay/Unit</div>
          <div class="v">{profile.barangay}</div>
        </article>
        <article class="item">
          <div class="k">Shift</div>
          <div class="v">{profile.shift}</div>
        </article>
        <article class="item">
          <div class="k">Member Since</div>
          <div class="v">{profile.memberSince}</div>
        </article>
      </div>

      <div class="metrics">
        <div class="metric">
          <span class="n">{profile.assignedIncidents}</span>
          <span class="l">Assigned Incidents</span>
        </div>
        <div class="metric">
          <span class="n">{profile.resolvedToday}</span>
          <span class="l">Resolved Today</span>
        </div>
      </div>
    </div>
  </div>
</section>

<style>
  .profile-wrap {
    position: absolute;
    inset: 0;
    z-index: 650;
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 88px 24px 24px 324px;
    pointer-events: none;
  }

  .profile-card {
    width: min(860px, 100%);
    background: rgba(10, 10, 16, 0.94);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 18px;
    box-shadow: 0 18px 48px rgba(0, 0, 0, 0.45);
    backdrop-filter: blur(16px);
    pointer-events: auto;
    overflow: hidden;
  }

  .header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 14px 16px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .back-btn {
    display: flex;
    align-items: center;
    gap: 4px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    background: rgba(255, 255, 255, 0.04);
    color: #d0d0e0;
    padding: 7px 10px;
    border-radius: 10px;
    font-size: 12px;
    cursor: pointer;
  }
  .back-btn:hover { background: rgba(255, 255, 255, 0.08); }
  .title-wrap { flex: 1; min-width: 0; }
  .title-wrap h2 { font-size: 16px; color: #f0f0f5; }
  .title-wrap p { font-size: 11px; color: #808090; }
  .role-pill {
    font-size: 11px;
    font-weight: 600;
    padding: 5px 10px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.06);
    color: #b0b0c0;
  }
  .role-pill.admin {
    background: rgba(0, 200, 150, 0.12);
    color: #00c896;
    border: 1px solid rgba(0, 200, 150, 0.26);
  }

  .body { padding: 16px; }
  .avatar-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-bottom: 14px;
    margin-bottom: 14px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .avatar {
    width: 46px;
    height: 46px;
    border-radius: 12px;
    background: linear-gradient(135deg, #00c896, #00a378);
    color: #0a1410;
    display: grid;
    place-items: center;
    font-weight: 700;
  }
  .name { color: #f0f0f5; font-weight: 600; font-size: 14px; }
  .muted { color: #808090; font-size: 12px; }

  .grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 10px;
    margin-bottom: 14px;
  }
  .item {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 12px;
    padding: 10px;
  }
  .k { font-size: 11px; color: #707080; margin-bottom: 4px; }
  .v { font-size: 13px; color: #e6e6ef; font-weight: 500; }

  .metrics {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 10px;
  }
  .metric {
    background: rgba(0, 200, 150, 0.08);
    border: 1px solid rgba(0, 200, 150, 0.2);
    border-radius: 12px;
    padding: 10px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .n { font-size: 22px; color: #00c896; font-weight: 700; line-height: 1.1; }
  .l { font-size: 11px; color: #8acfb8; }
</style>
