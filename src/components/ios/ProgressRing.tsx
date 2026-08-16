import { motion } from "motion/react";

export function ProgressRing({
  value,
  size = 54,
  stroke = 6,
  color = "var(--ios-green)",
  children,
  label,
}: {
  value: number;
  size?: number;
  stroke?: number;
  color?: string;
  children?: React.ReactNode;
  label?: string;
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <div className="relative grid place-items-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="currentColor"
          className="text-foreground/10"
          strokeWidth={stroke}
        />
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          initial={{ strokeDashoffset: c }}
          animate={{ strokeDashoffset: c - (Math.min(100, Math.max(0, value)) / 100) * c }}
          transition={{ type: "spring", stiffness: 120, damping: 24 }}
          style={{
            filter: size > 60 ? `drop-shadow(0 0 4px color-mix(in oklab, ${color} 35%, transparent))` : undefined,
          }}
        />
      </svg>
      <div className="absolute inset-0 grid place-items-center leading-none">
        {children ?? (
          <span
            className="font-semibold tabular-nums tracking-tight text-foreground"
            style={{ fontSize: size * 0.26 }}
          >
            {Math.round(value)}
          </span>
        )}
        {label ? (
          <span className="absolute bottom-1 text-[8px] tracking-widest text-muted-foreground">
            {label}
          </span>
        ) : null}
      </div>
    </div>
  );
}
