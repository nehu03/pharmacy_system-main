(function () {
  var SESSION_KEY = 'meditSession';

  function mapProfileToSession(user, profile) {
    var r = profile && profile.role ? profile.role : 'customer';
    var sessionRole = r === 'customer' ? 'customer' : r;
    return {
      id: user.id,
      name: (profile && profile.full_name) || user.email || '',
      email: user.email || '',
      role: sessionRole,
      username: (profile && profile.username) || '',
      loginTime: new Date().toISOString(),
      source: 'supabase'
    };
  }

  function persistSession(sessionObj, remember) {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(sessionObj));
    if (remember) localStorage.setItem(SESSION_KEY, JSON.stringify(sessionObj));
  }

  function redirectForRole(profile) {
    var r = profile && profile.role ? profile.role : 'customer';
    if (r === 'admin' || r === 'staff') {
      location.href = 'admin.html';
    } else if (r === 'cashier') {
      location.href = 'cashier.html';
    } else {
      location.href = 'onlinepharmacy.html';
    }
  }

  async function hydrateSession() {
    var sb = typeof window.MeditSupabase === 'function' ? window.MeditSupabase() : null;
    if (!sb) return;
    var result = await sb.auth.getSession();
    var session = result && result.data ? result.data.session : null;
    if (!session) return;
    var userRes = await sb.auth.getUser();
    var user = userRes && userRes.data ? userRes.data.user : null;
    if (!user) return;
    var profRes = await sb.from('profiles').select('*').eq('id', user.id).maybeSingle();
    var profile = profRes && profRes.data ? profRes.data : null;
    if (!profile) return;
    var remember = !!localStorage.getItem(SESSION_KEY);
    persistSession(mapProfileToSession(user, profile), remember);
  }

  window.MeditAuth = {
    SESSION_KEY: SESSION_KEY,
    mapProfileToSession: mapProfileToSession,
    persistSession: persistSession,
    redirectForRole: redirectForRole,
    hydrateSession: hydrateSession
  };
  window.MeditAuthHydrateSession = hydrateSession;
})();
