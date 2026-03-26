import React from "react";
import { Composition } from "remotion";
import { OneIntro } from "./OneIntro";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="OneIntro"
        component={OneIntro}
        durationInFrames={300}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};
