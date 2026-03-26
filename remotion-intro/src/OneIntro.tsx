import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Sequence,
  Easing,
} from "remotion";

// ── Colour palette ──────────────────────────────────────────────────────────
const BG = "#0A0A0F";
const ACCENT = "#C8A97E"; // warm gold
const WHITE = "#F5F0EB";
const MUTED = "#6B6B7A";
const CARD_BG = "#13131A";

// ── Helpers ──────────────────────────────────────────────────────────────────
function useSpring(frame: number, delay = 0, stiffness = 100, damping = 14) {
  const { fps } = useVideoConfig();
  return spring({ fps, frame: frame - delay, config: { stiffness, damping }, durationInFrames: 40 });
}

function fadeIn(frame: number, start: number, duration = 20) {
  return interpolate(frame, [start, start + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
}

function slideUp(frame: number, start: number, distance = 40, duration = 25) {
  return interpolate(frame, [start, start + duration], [distance, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
}

// ── Background gradient ───────────────────────────────────────────────────────
const Background: React.FC<{ frame: number }> = ({ frame }) => {
  const pulse = interpolate(
    Math.sin((frame / 120) * Math.PI),
    [-1, 1],
    [0.03, 0.09]
  );
  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(ellipse 90% 70% at 50% 20%, rgba(200,169,126,${pulse}) 0%, transparent 70%), ${BG}`,
      }}
    />
  );
};

// ── Floating orb decoration ───────────────────────────────────────────────────
const Orb: React.FC<{ x: number; y: number; size: number; frame: number; offset?: number }> = ({
  x, y, size, frame, offset = 0,
}) => {
  const dy = Math.sin(((frame + offset) / 90) * Math.PI) * 12;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y + dy,
        width: size,
        height: size,
        borderRadius: "50%",
        background: `radial-gradient(circle, rgba(200,169,126,0.18) 0%, transparent 70%)`,
        filter: "blur(40px)",
      }}
    />
  );
};

// ── Particle dots ─────────────────────────────────────────────────────────────
const Particles: React.FC<{ frame: number }> = ({ frame }) => {
  const dots = React.useMemo(
    () =>
      Array.from({ length: 28 }, (_, i) => ({
        x: ((i * 137.5) % 1080),
        y: ((i * 233.1) % 1920),
        size: 1.5 + (i % 3),
        opacity: 0.15 + ((i % 5) * 0.06),
        speed: 0.3 + (i % 4) * 0.15,
      })),
    []
  );
  return (
    <>
      {dots.map((d, i) => {
        const fy = ((d.y - d.speed * frame) % 1920 + 1920) % 1920;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: d.x,
              top: fy,
              width: d.size,
              height: d.size,
              borderRadius: "50%",
              backgroundColor: ACCENT,
              opacity: d.opacity,
            }}
          />
        );
      })}
    </>
  );
};

// ── Section 1: Logo intro (frames 0–89) ──────────────────────────────────────
const LogoScene: React.FC = () => {
  const frame = useCurrentFrame();
  const s = useSpring(frame, 5);
  const opacity = fadeIn(frame, 0, 18);
  const scale = interpolate(s, [0, 1], [0.7, 1]);
  const lineW = interpolate(frame, [30, 70], [0, 220], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const subOpacity = fadeIn(frame, 55, 25);
  const subY = slideUp(frame, 55, 30);

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      {/* big ONE */}
      <div
        style={{
          opacity,
          transform: `scale(${scale})`,
          textAlign: "center",
        }}
      >
        <div
          style={{
            fontFamily: "'SF Pro Display', 'Helvetica Neue', Arial, sans-serif",
            fontSize: 180,
            fontWeight: 700,
            letterSpacing: -8,
            color: WHITE,
            lineHeight: 1,
          }}
        >
          ONE
        </div>

        {/* animated underline */}
        <div
          style={{
            margin: "16px auto 0",
            height: 2,
            width: lineW,
            background: `linear-gradient(90deg, transparent, ${ACCENT}, transparent)`,
            borderRadius: 1,
          }}
        />

        {/* tagline */}
        <div
          style={{
            marginTop: 28,
            opacity: subOpacity,
            transform: `translateY(${subY}px)`,
            fontFamily: "'SF Pro Text', 'Helvetica Neue', Arial, sans-serif",
            fontSize: 32,
            fontWeight: 300,
            color: MUTED,
            letterSpacing: 6,
            textTransform: "uppercase",
          }}
        >
          her günün bir anısı
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ── Feature card component ────────────────────────────────────────────────────
const FeatureCard: React.FC<{
  icon: string;
  title: string;
  desc: string;
  frame: number;
  delay: number;
  color?: string;
}> = ({ icon, title, desc, frame, delay, color = ACCENT }) => {
  const s = useSpring(frame, delay, 120, 16);
  const opacity = fadeIn(frame, delay, 20);
  const y = interpolate(s, [0, 1], [60, 0]);

  return (
    <div
      style={{
        opacity,
        transform: `translateY(${y}px)`,
        background: CARD_BG,
        border: `1px solid rgba(200,169,126,0.15)`,
        borderRadius: 24,
        padding: "40px 44px",
        display: "flex",
        flexDirection: "column",
        gap: 14,
      }}
    >
      <div style={{ fontSize: 52 }}>{icon}</div>
      <div
        style={{
          fontFamily: "'SF Pro Display', 'Helvetica Neue', Arial, sans-serif",
          fontSize: 36,
          fontWeight: 600,
          color: WHITE,
          letterSpacing: -0.5,
        }}
      >
        {title}
      </div>
      <div
        style={{
          fontFamily: "'SF Pro Text', 'Helvetica Neue', Arial, sans-serif",
          fontSize: 26,
          fontWeight: 300,
          color: MUTED,
          lineHeight: 1.5,
        }}
      >
        {desc}
      </div>
      <div
        style={{
          width: 40,
          height: 2,
          background: color,
          borderRadius: 1,
          marginTop: 4,
        }}
      />
    </div>
  );
};

// ── Section 2: Features (frames 90–219) ──────────────────────────────────────
const FeaturesScene: React.FC = () => {
  const frame = useCurrentFrame();
  const titleOpacity = fadeIn(frame, 5, 25);
  const titleY = slideUp(frame, 5, 30);

  const features = [
    { icon: "🌙", title: "Günlük Mood", desc: "Her günün duygusunu bir dokunuşla kaydet", delay: 20 },
    { icon: "🎵", title: "Müzik Anıları", desc: "O anın şarkısı, Spotify ile otomatik", delay: 45 },
    { icon: "📸", title: "Fotoğraf & Notlar", desc: "Günü fotoğraf ve kelimelerle yaşat", delay: 70 },
    { icon: "👥", title: "Arkadaş Çemberi", desc: "Sevdiklerinle günü paylaş", delay: 95 },
  ];

  return (
    <AbsoluteFill
      style={{
        padding: "80px 72px",
        justifyContent: "center",
        gap: 32,
        flexDirection: "column",
      }}
    >
      {/* section heading */}
      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          fontFamily: "'SF Pro Display', 'Helvetica Neue', Arial, sans-serif",
          fontSize: 28,
          fontWeight: 400,
          color: ACCENT,
          letterSpacing: 5,
          textTransform: "uppercase",
          marginBottom: 8,
        }}
      >
        Özellikler
      </div>

      {features.map((f) => (
        <FeatureCard key={f.title} frame={frame} {...f} />
      ))}
    </AbsoluteFill>
  );
};

// ── Section 3: Mood ring / closing (frames 220–299) ──────────────────────────
const ClosingScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const s = spring({ fps, frame, config: { stiffness: 80, damping: 14 }, durationInFrames: 40 });
  const scale = interpolate(s, [0, 1], [0.5, 1]);
  const opacity = fadeIn(frame, 0, 20);
  const ringScale = interpolate(frame, [20, 55], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const subOpacity = fadeIn(frame, 45, 25);
  const subY = slideUp(frame, 45, 30);
  const ctaOpacity = fadeIn(frame, 65, 20);

  // pulsing ring
  const ringPulse = interpolate(
    Math.sin((frame / 40) * Math.PI),
    [-1, 1],
    [0.6, 1]
  );

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      {/* concentric rings */}
      {[220, 160, 100].map((size, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            width: size * ringScale,
            height: size * ringScale,
            borderRadius: "50%",
            border: `${1.5 - i * 0.3}px solid rgba(200,169,126,${(0.25 - i * 0.06) * ringPulse})`,
          }}
        />
      ))}

      {/* logo mark */}
      <div
        style={{
          opacity,
          transform: `scale(${scale})`,
          textAlign: "center",
          zIndex: 2,
        }}
      >
        <div
          style={{
            fontFamily: "'SF Pro Display', 'Helvetica Neue', Arial, sans-serif",
            fontSize: 96,
            fontWeight: 700,
            letterSpacing: -4,
            color: WHITE,
            lineHeight: 1,
          }}
        >
          ONE
        </div>

        <div
          style={{
            opacity: subOpacity,
            transform: `translateY(${subY}px)`,
            marginTop: 20,
            fontFamily: "'SF Pro Text', 'Helvetica Neue', Arial, sans-serif",
            fontSize: 28,
            fontWeight: 300,
            color: MUTED,
            letterSpacing: 3,
          }}
        >
          bugün neler hissettin?
        </div>

        {/* CTA pill */}
        <div
          style={{
            opacity: ctaOpacity,
            marginTop: 52,
            display: "inline-block",
            padding: "18px 60px",
            borderRadius: 100,
            background: `linear-gradient(135deg, ${ACCENT}, #A8845A)`,
          }}
        >
          <span
            style={{
              fontFamily: "'SF Pro Text', 'Helvetica Neue', Arial, sans-serif",
              fontSize: 30,
              fontWeight: 600,
              color: "#0A0A0F",
              letterSpacing: 1,
            }}
          >
            Hemen İndir
          </span>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ── Transition flash ──────────────────────────────────────────────────────────
const Flash: React.FC<{ frame: number }> = ({ frame }) => {
  const opacity = interpolate(frame, [0, 8], [0.6, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  if (opacity <= 0) return null;
  return (
    <AbsoluteFill
      style={{ backgroundColor: WHITE, opacity, pointerEvents: "none" }}
    />
  );
};

// ── Main composition ──────────────────────────────────────────────────────────
export const OneIntro: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ backgroundColor: BG, overflow: "hidden" }}>
      <Background frame={frame} />
      <Particles frame={frame} />

      {/* Decorative orbs */}
      <Orb x={-80} y={200} size={500} frame={frame} offset={0} />
      <Orb x={700} y={1400} size={400} frame={frame} offset={45} />

      {/* Scene 1 – Logo */}
      <Sequence from={0} durationInFrames={90}>
        <LogoScene />
      </Sequence>

      {/* Flash transition 1→2 */}
      <Sequence from={88} durationInFrames={12}>
        <Flash frame={useCurrentFrame()} />
      </Sequence>

      {/* Scene 2 – Features */}
      <Sequence from={90} durationInFrames={130}>
        <FeaturesScene />
      </Sequence>

      {/* Flash transition 2→3 */}
      <Sequence from={218} durationInFrames={12}>
        <Flash frame={useCurrentFrame()} />
      </Sequence>

      {/* Scene 3 – Closing */}
      <Sequence from={220} durationInFrames={80}>
        <ClosingScene />
      </Sequence>
    </AbsoluteFill>
  );
};
