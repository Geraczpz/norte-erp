export abstract class ApplicationError extends Error {
  public abstract readonly code: string;
  public abstract readonly statusCode: number;

  protected constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = new.target.name;
  }
}
