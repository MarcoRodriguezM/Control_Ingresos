import useStore from './store/useStore'

function App() {
  const { count, increment, decrement, reset } = useStore()

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold text-center mb-8 text-gray-800">
          React + Zustand + Tailwind + Bootstrap
        </h1>
        
        <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
          <h2 className="text-2xl font-semibold mb-4 text-gray-700">Contador con Zustand</h2>
          <div className="text-center mb-6">
            <span className="text-6xl font-bold text-blue-600">{count}</span>
          </div>
          
          <div className="flex justify-center gap-3 mb-4">
            <button 
              onClick={decrement}
              className="btn btn-primary"
            >
              Decrementar
            </button>
            <button 
              onClick={increment}
              className="btn btn-success"
            >
              Incrementar
            </button>
            <button 
              onClick={reset}
              className="btn btn-danger"
            >
              Reset
            </button>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <h2 className="text-2xl font-semibold mb-4 text-gray-700">Ejemplo de Bootstrap y Tailwind</h2>
          <div className="row">
            <div className="col-md-4 mb-3">
              <div className="card h-100">
                <div className="card-body">
                  <h5 className="card-title">Tailwind CSS</h5>
                  <p className="card-text text-gray-600">
                    Estilos utility-first para diseño rápido
                  </p>
                  <button className="btn btn-outline-primary btn-sm">Más info</button>
                </div>
              </div>
            </div>
            <div className="col-md-4 mb-3">
              <div className="card h-100">
                <div className="card-body">
                  <h5 className="card-title">Bootstrap</h5>
                  <p className="card-text text-gray-600">
                    Framework CSS para componentes UI
                  </p>
                  <button className="btn btn-outline-secondary btn-sm">Más info</button>
                </div>
              </div>
            </div>
            <div className="col-md-4 mb-3">
              <div className="card h-100">
                <div className="card-body">
                  <h5 className="card-title">Zustand</h5>
                  <p className="card-text text-gray-600">
                    State management ligero y simple
                  </p>
                  <button className="btn btn-outline-success btn-sm">Más info</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
