/**
 * errorHandler — centralized error response, tránh leak stack ra client production.
 */
import { Request, Response, NextFunction } from "express";
import { env } from "../config/env";
import { ZodError } from "zod";

export function notFound(_req: Request, res: Response): void {
  res.status(404).json({ error: "Not Found" });
}

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof ZodError) {
    res.status(400).json({
      error: "ValidationError",
      details: err.flatten(),
    });
    return;
  }

  const status =
    typeof err === "object" && err !== null && "status" in err
      ? Number((err as { status: number }).status)
      : 500;

  const message =
    err instanceof Error ? err.message : "Internal Server Error";

  if (env.NODE_ENV !== "production") {
    console.error(err);
  }

  res.status(Number.isFinite(status) ? status : 500).json({
    error: status === 500 ? "InternalServerError" : "Error",
    message,
  });
}
