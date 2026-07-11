// Provides the AppServices container (mocks until Supabase is wired) to the
// whole tree, mirroring how the Swift app injects AppServices.
import React, { createContext, useContext, useMemo } from "react";
import { AppServices, createAppServices } from "../services";

const ServicesContext = createContext<AppServices | null>(null);

export const ServicesProvider = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  const services = useMemo(() => createAppServices(), []);
  return (
    <ServicesContext.Provider value={services}>
      {children}
    </ServicesContext.Provider>
  );
};

export const useServices = (): AppServices => {
  const ctx = useContext(ServicesContext);
  if (!ctx) throw new Error("useServices must be used within ServicesProvider");
  return ctx;
};
