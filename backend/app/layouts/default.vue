<script setup lang="ts">
const auth = useAuth()
const route = useRoute()

const nav = [
  { to: '/', label: 'Dashboard' },
  { to: '/denetim', label: 'Denetim Kuyruğu' },
  { to: '/work-orders', label: 'İş Emirleri' },
  { to: '/map', label: 'Canlı Harita' },
  { to: '/saha-haritasi', label: 'Saha Haritası' },
  { to: '/saha-durumu', label: 'Saha Durumu' },
  { to: '/sites', label: 'Sahalar' },
  { to: '/equipment', label: 'Ekipmanlar' },
  { to: '/teams', label: 'Ekipler' },
  { to: '/users', label: 'Kullanıcılar' },
  { to: '/reports', label: 'Raporlar' },
]
</script>

<template>
  <div class="shell">
    <aside class="sidebar">
      <div class="brand">SahaCheck</div>
      <nav>
        <NuxtLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          class="nav-link"
          :class="{ active: route.path === item.to }"
        >
          {{ item.label }}
        </NuxtLink>
      </nav>
      <div class="sidebar-footer">
        <div class="user-name">{{ auth.user.value?.ad }}</div>
        <div class="user-role muted">{{ auth.user.value?.rol }}</div>
        <button class="btn" style="width: 100%; margin-top: 8px" @click="auth.logout()">Çıkış yap</button>
      </div>
    </aside>
    <main class="content">
      <slot />
    </main>
  </div>
</template>

<style scoped>
.shell {
  display: flex;
  min-height: 100vh;
}
.sidebar {
  width: 220px;
  flex-shrink: 0;
  background: var(--surface);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  padding: 16px 12px;
}
.brand {
  font-weight: 700;
  font-size: 16px;
  padding: 8px 10px 20px;
}
nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
}
.nav-link {
  padding: 9px 10px;
  border-radius: var(--radius);
  color: var(--text-muted);
  text-decoration: none;
  font-size: 14px;
  font-weight: 500;
}
.nav-link:hover {
  background: var(--bg);
  color: var(--text);
}
.nav-link.active {
  background: #eff6ff;
  color: var(--accent);
}
.sidebar-footer {
  border-top: 1px solid var(--border);
  padding: 12px 10px 4px;
}
.user-name {
  font-weight: 600;
  font-size: 13px;
}
.user-role {
  font-size: 12px;
}
.content {
  flex: 1;
  padding: 28px 32px;
  max-width: 1200px;
}
</style>
