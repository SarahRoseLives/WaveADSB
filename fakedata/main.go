package main

import (
	"fmt"
	"log"
	"math"
	"math/rand"
	"net"
	"sync" // Import the sync package for Mutex
	"time"
)

const (
	// Target coordinates for Ashtabula, OH
	targetLat = 41.88
	targetLon = -80.79
)

// Aircraft represents a simulated aircraft
type Aircraft struct {
	ICAO        string
	Callsign    string
	Latitude    float64
	Longitude   float64
	Altitude    int
	GroundSpeed int
	Track       int

	// Internal simulation parameters
	startLat  float64 // Starting position
	startLon  float64
	latRate   float64 // How much to change lat per update
	lonRate   float64 // How much to change lon per update
	altRate   int
	callsignSet bool
}

// --- Global State ---
// We use global state with a mutex to ensure all clients see
// the same stable simulation.
var (
	// A slice of pointers to our aircraft
	globalAircraft []*Aircraft
	// A Read/Write mutex to protect the slice
	// We use RWMutex because there are many readers (clients)
	// and only one writer (the simulation ticker).
	aircraftMutex = &sync.RWMutex{}
)

// --- End Global State ---

// newAircraft initializes an aircraft to fly over the target
func newAircraft(icao, callsign string, startLat, startLon, speedFactor float64, startAlt, altRate, startSpeed int) *Aircraft {
	// Calculate the vector from start to target
	deltaLat := targetLat - startLat
	deltaLon := targetLon - startLon
	distance := math.Sqrt(deltaLat*deltaLat + deltaLon*deltaLon)

	// Calculate a constant rate of change based on the speed factor
	latRate := (deltaLat / distance) * speedFactor
	lonRate := (deltaLon / distance) * speedFactor

	// Calculate the track (heading)
	trackRad := math.Atan2(deltaLon, deltaLat)
	trackDeg := int(trackRad * (180 / math.Pi))
	if trackDeg < 0 {
		trackDeg += 360
	}

	return &Aircraft{
		ICAO:        icao,
		Callsign:    callsign,
		Latitude:    startLat,
		Longitude:   startLon,
		Altitude:    startAlt,
		GroundSpeed: startSpeed,
		Track:       trackDeg,
		startLat:    startLat,
		startLon:    startLon,
		latRate:     latRate,
		lonRate:     lonRate,
		altRate:     altRate,
		callsignSet: false,
	}
}

// update simulates the aircraft's movement.
// This should only be called by the single global simulation loop.
func (ac *Aircraft) update() {
	ac.Latitude += ac.latRate
	ac.Longitude += ac.lonRate
	ac.Altitude += ac.altRate

	// Make the altitude change direction
	if ac.Altitude > 38000 || ac.Altitude < 25000 {
		ac.altRate *= -1
	}

	// If it flies too far past the target (e.g., 1 degree, ~70 miles), reset it
	// to its starting position to fly over again.
	if math.Abs(ac.Latitude-ac.startLat) > 1.0 || math.Abs(ac.Longitude-ac.startLon) > 1.0 {
		ac.Latitude = ac.startLat
		ac.Longitude = ac.startLon
		log.Printf("Resetting %s to start position", ac.Callsign)
	}
}

// formatTime generates the two timestamp fields for the SBS-1 message
func formatTime() (string, string) {
	now := time.Now().UTC()
	dateStr := now.Format("2006/01/02")
	timeStr := now.Format("15:04:05.000")
	return dateStr, timeStr
}

// generateMsg1 creates a callsign message (MSG,1)
func (ac *Aircraft) generateMsg1() string {
	date, time := formatTime()
	ac.callsignSet = true // Mark that we've sent the callsign
	// MSG,1,1,1,ICAO,1,DATE,TIME,DATE,TIME,CALLSIGN,,,,,,,,,,0
	return fmt.Sprintf("MSG,1,1,1,%s,1,%s,%s,%s,%s,%s,,,,,,,,,,,0\n",
		ac.ICAO, date, time, date, time, ac.Callsign)
}

// generateMsg3 creates an airborne position message (MSG,3)
func (ac *Aircraft) generateMsg3() string {
	date, time := formatTime()
	// *** THIS IS THE CORRECTED FORMAT ***
	// Note: ,,%d,,,%.5f,%.5f,
	//       Field 11 (Alt), 12, 13, 14 (Lat), 15 (Lon)
	// MSG,3,1,1,ICAO,1,DATE,TIME,DATE,TIME,,ALTITUDE,,,LAT,LON,,,0,,0,0
	return fmt.Sprintf("MSG,3,1,1,%s,1,%s,%s,%s,%s,,%d,,,%.5f,%.5f,,,0,,0,0\n",
		ac.ICAO, date, time, date, time, ac.Altitude, ac.Latitude, ac.Longitude)
}

// generateMsg4 creates an airborne velocity message (MSG,4)
func (ac *Aircraft) generateMsg4() string {
	date, time := formatTime()
	// MSG,4,1,1,ICAO,1,DATE,TIME,DATE,TIME,,,SPEED,TRACK,,,,,0
	return fmt.Sprintf("MSG,4,1,1,%s,1,%s,%s,%s,%s,,,%d,%d,,,-64,,,,,0\n",
		ac.ICAO, date, time, date, time, ac.GroundSpeed, ac.Track)
}

// handleConnection streams fake data to a single client
func handleConnection(conn net.Conn) {
	log.Printf("Client connected: %s", conn.RemoteAddr())
	defer conn.Close()
	defer log.Printf("Client disconnected: %s", conn.RemoteAddr())

	// Ticker to send data to this client
	// We send a burst of 3 messages (one for each plane) every second
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		// --- Read Lock ---
		// We get a "Read Lock", which allows many clients to read
		// at the same time. It waits if the simulation is currently
		// "Write Locked" (i.e., updating positions).
		aircraftMutex.RLock()

		// Iterate over the global aircraft list
		for _, ac := range globalAircraft {
			var msg string
			// Send a callsign message first, then stick to pos/vel
			if !ac.callsignSet || rand.Intn(10) < 2 { // 20% chance to re-send callsign
				msg = ac.generateMsg1()
			} else if rand.Intn(2) == 0 { // 50/50 pos or vel
				msg = ac.generateMsg3()
			} else {
				msg = ac.generateMsg4()
			}

			// Try to write to the client
			_, err := conn.Write([]byte(msg))
			if err != nil {
				// If we can't write, unlock and return, closing the connection
				log.Printf("Write error: %v", err)
				aircraftMutex.RUnlock()
				return
			}
		}

		// --- Read Unlock ---
		// Release the lock so other goroutines can run
		aircraftMutex.RUnlock()
	}
}

// runGlobalSimulation is a single goroutine that updates all aircraft
func runGlobalSimulation() {
	// Ticker for simulation updates (e.g., 10 times a second)
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for range ticker.C {
		// --- Write Lock ---
		// Get an exclusive "Write Lock". All client handlers
		// will pause until we are done updating.
		aircraftMutex.Lock()
		for _, ac := range globalAircraft {
			ac.update()
		}
		// --- Write Unlock ---
		aircraftMutex.Unlock()
	}
}

func main() {
	port := 30003
	log.Printf("Starting fake ADS-B (SBS-1) server on port %d...", port)
	log.Printf("Simulating 3-aircraft fly-over of Ashtabula, OH (%.4f, %.4f)", targetLat, targetLon)

	// Initialize our 3 simulated aircraft
	globalAircraft = []*Aircraft{
		// 1. Starts SW, flies NE
		newAircraft("A1A1A1", "DAL789",
			targetLat-0.5, targetLon-0.5, // Start SW
			0.0003,  // Slower, more realistic speed factor
			30000, 2, 450, // startAlt, altRate, groundSpeed
		),
		// 2. Starts NW, flies SE
		newAircraft("B2B2B2", "AAL123",
			targetLat+0.5, targetLon-0.5, // Start NW
			0.00035, // speedFactor
			35000, -1, 500, // startAlt, altRate, groundSpeed
		),
		// 3. Starts S, flies N
		newAircraft("C3C3C3", "SWA456",
			targetLat-0.5, targetLon+0.1, // Start S/SE
			0.00028, // speedFactor
			28000, 1, 420, // startAlt, altRate, groundSpeed
		),
	}

	// --- Start the ONE global simulation loop ---
	go runGlobalSimulation()

	// Start the TCP listener
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to start listener: %v", err)
	}
	defer listener.Close()

	// Accept client connections forever
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Failed to accept connection: %v", err)
			continue
		}
		// Handle each connection in its own goroutine
		// It no longer passes the aircraft list
		go handleConnection(conn)
	}
}

