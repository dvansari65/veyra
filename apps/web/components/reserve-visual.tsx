export function ReserveVisual() {
  return (
    <figure className="reserve-visual">
      <div className="visual-coordinate">
        <span>V / 001</span>
        <span>CAPITAL IN RESERVE</span>
      </div>
      <div className="reserve-art">
        <img
          src="/capital-reserve.webp"
          alt="Sculpture of graphite capital allocations held together by a vermilion clamp."
          width={1120}
          height={1400}
          fetchPriority="high"
        />
      </div>
      <figcaption className="visual-caption">
        <span className="caption-marker" aria-hidden="true">
          ↳
        </span>
        <div>
          <strong>A commitment with substance.</strong>
          <span>Funded. Allocated. Ready for settlement.</span>
        </div>
        <span className="caption-index" aria-hidden="true">
          [ 01 ]
        </span>
      </figcaption>
    </figure>
  );
}
