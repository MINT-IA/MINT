// Count-up animé — le chiffre qui se pose, comme dans le DS Flutter (MintCountUp)
// Usage : <CountUp value={2991} duration={900} />

function CountUp({ value, duration = 900, format = (v) => fmtCHF(v), startDelay = 0, trigger = 0 }) {
  const [display, setDisplay] = React.useState(0);
  const rafRef = React.useRef();
  const startedRef = React.useRef(false);

  React.useEffect(() => {
    startedRef.current = false;
    setDisplay(0);
    const startTimer = setTimeout(() => {
      startedRef.current = true;
      const start = performance.now();
      const from = 0;
      const to = value;
      const animate = (now) => {
        const elapsed = now - start;
        const t = Math.min(elapsed / duration, 1);
        // easeOutCubic
        const eased = 1 - Math.pow(1 - t, 3);
        setDisplay(from + (to - from) * eased);
        if (t < 1) rafRef.current = requestAnimationFrame(animate);
      };
      rafRef.current = requestAnimationFrame(animate);
    }, startDelay);
    return () => {
      clearTimeout(startTimer);
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [value, duration, startDelay, trigger]);

  return <>{format(display)}</>;
}

Object.assign(window, { CountUp });
