(function () {
  function getClient() {
    var url = window.MEDIT_SUPABASE_URL;
    var key = window.MEDIT_SUPABASE_ANON_KEY;
    if (!url || !key || !String(url).trim() || !String(key).trim()) return null;
    if (!window.supabase || typeof window.supabase.createClient !== 'function') return null;
    if (!window._meditSb) {
      window._meditSb = window.supabase.createClient(url.trim(), key.trim());
    }
    return window._meditSb;
  }
  window.MeditSupabase = getClient;
})();
