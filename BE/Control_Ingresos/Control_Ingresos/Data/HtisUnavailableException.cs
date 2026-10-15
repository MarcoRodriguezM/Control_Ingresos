namespace Control_Ingresos.Data;

public sealed class HtisUnavailableException(string message, Exception? innerException = null)
    : Exception(message, innerException);
