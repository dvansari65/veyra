export function BrandMark({ className = '' }: { className?: string }) {
  return (
    <svg
      className={className}
      width="36"
      height="36"
      viewBox="0 0 40 40"
      fill="none"
      aria-hidden="true"
    >
      <path d="M3 8h10l8 22-6 4L3 8Z" fill="currentColor" />
      <path d="M26 8h11L25 34h-9L26 8Z" fill="currentColor" />
      <path d="m27 3 9 0-2 4h-9l2-4Z" fill="currentColor" opacity=".45" />
    </svg>
  );
}
export function Arrow({ diagonal = false, down = false }: { diagonal?: boolean; down?: boolean }) {
  return (
    <svg
      className={`arrow${down ? ' arrow-down' : ''}`}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path
        d={diagonal ? 'M6 18 18 6M6 6h12v12' : 'M4 12h15m-6-6 6 6-6 6'}
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
export function Check() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="m6 12 4 4 8-8"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
export function ReserveIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M4 9V4h5m6 0h5v5m0 6v5h-5m-6 0H4v-5M8 8h8v8H8z"
        stroke="currentColor"
        strokeWidth="1.4"
      />
    </svg>
  );
}
