const CACHE="milou-ops-v6";
const APP_SHELL=["/","/manifest.webmanifest","/milou-icon.svg","/milou-icon-maskable.svg"];

self.addEventListener("install",event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(APP_SHELL)).then(()=>self.skipWaiting()));
});

self.addEventListener("activate",event=>{
  event.waitUntil(
    caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener("fetch",event=>{
  const req=event.request;
  if(req.method!=="GET")return;
  const url=new URL(req.url);

  // Never cache Supabase/OpenAI/Shopify or third-party API traffic.
  if(url.origin!==self.location.origin)return;

  // Navigation: network first so new deployments appear immediately.
  if(req.mode==="navigate"){
    event.respondWith(
      fetch(req).then(res=>{
        const copy=res.clone();
        caches.open(CACHE).then(cache=>cache.put("/",copy));
        return res;
      }).catch(()=>caches.match("/"))
    );
    return;
  }

  // Local static assets: cache first, then network.
  event.respondWith(
    caches.match(req).then(cached=>cached||fetch(req).then(res=>{
      if(res.ok){
        const copy=res.clone();
        caches.open(CACHE).then(cache=>cache.put(req,copy));
      }
      return res;
    }))
  );
});