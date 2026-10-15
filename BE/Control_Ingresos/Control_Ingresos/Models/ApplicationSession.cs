namespace Control_Ingresos.Models;

public sealed class ApplicationSession
{
    public const string ClaimType = "control_ingresos_application_session";

    public string InstanceId { get; } = Guid.NewGuid().ToString("N");
}
