namespace Control_Ingresos.Data;

public sealed class SingularUnavailableException : Exception
{
    public SingularUnavailableException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
