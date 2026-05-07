// Server component — vanilla JS scroll observer attached via inline <script>.
// No hydration cost; saves ~14KB React runtime.
const SECTION_IDS = ["hero", "lesson-1", "lesson-2", "lesson-3", "lesson-4"];
const LABELS = [
  "Lesson 0 · pre-flight",
  "Lesson 1 · what this is",
  "Lesson 2 · the tone",
  "Lesson 3 · abstention",
  "Lesson 4 · on-device proof",
];

const INLINE_OBSERVER_SCRIPT = `(function(){
  var ids=['hero','lesson-1','lesson-2','lesson-3','lesson-4'];
  var pips=document.querySelectorAll('.progress-rail .pip');
  if(!pips.length) return;
  var obs=new IntersectionObserver(function(es){
    es.forEach(function(e){
      if(!e.isIntersecting) return;
      var idx=ids.indexOf(e.target.id);
      if(idx<0) return;
      pips.forEach(function(p,i){
        p.classList.toggle('active', i===idx);
        p.classList.toggle('done', i<idx);
      });
    });
  },{rootMargin:'-30% 0px -50% 0px'});
  ids.forEach(function(id){var el=document.getElementById(id); if(el) obs.observe(el);});
})();`;

export default function ProgressRail() {
  return (
    <>
      <div className="progress-rail" role="progressbar" aria-label="Reading progress">
        <span>He Was Socrates · gate H1</span>
        <div className="pips">
          {SECTION_IDS.map((id, i) => (
            <div
              key={id}
              className={`pip${i === 0 ? " active" : ""}`}
              title={LABELS[i]}
            />
          ))}
        </div>
        <div className="meta-right">
          <span>Profile · max</span>
          <span>Run · r-20260507-010321</span>
        </div>
      </div>
      <script dangerouslySetInnerHTML={{ __html: INLINE_OBSERVER_SCRIPT }} />
    </>
  );
}
