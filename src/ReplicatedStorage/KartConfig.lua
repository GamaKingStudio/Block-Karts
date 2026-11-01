local KartConfig = {
	-- Parámetros de Spawn
	SpawnSpacing = 12,

	-- Parámetros físicos base
	MaxSpeed = 75,
	ForwardAcceleration = 48,
	ReverseMaxSpeed = 22,
	ReverseAcceleration = 25,
	BrakeDeceleration = 65,
	CoastDeceleration = 12,
	SteerSpeed = 2.4,
	Grip = 18,

	-- Parámetros de Derrape y Mini-Turbo
	DriftMinSpeed = 8,
	DriftGripMultiplier = 0.25,
	DriftSteerMultiplier = 1.6,
	DriftMinDuration = 0.8,
	MiniTurboDuration = 0.75,
	MiniTurboAccelMultiplier = 1.45,
	MiniTurboSpeedMultiplier = 1.25,

	-- Parámetros de Cámara Scriptable
	CameraDistance = 14,
	CameraHeight = 5.5,
	CameraLookAhead = 0.25,
	CameraLerpSpeed = 12,

	-- Parámetros del Sistema de Carreras y Checkpoints
	TOTAL_LAPS = 3,
	DEBUG_CHECKPOINTS = false, -- Cambiar a true para visualizar los volúmenes de trigger en Studio
	WRONG_WAY_DOT_THRESHOLD = -0.2, -- Umbral angular (coseno): < -0.2 indica sentido inverso
	RESPAWN_Y_OFFSET = 3.0, -- Elevación en studs sobre el último checkpoint válido
	CHECKPOINT_DEBOUNCE_TIME = 0.4, -- Tiempo mínimo entre lecturas consecutivas por jugador
}

return KartConfig