package serve

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type JsonData struct {
	Iridium_session_status int
	Momsn                  int
	Data                   string
	Serial                 int
	Imei                   string
	Device_type            string
	Iridium_latitude       float32
	Iridium_longitude      float32
	Iridium_cep            float32
	JWT                    string
	Transmit_time          string
}

type MsgClaims struct {
	jwt.StandardClaims
	Data  string `json:"data"`
	Momsn string `json:"momsn"`
}

var (
	popCount        *prometheus.GaugeVec
	popNames        []string = []string{"croco", "prochloro", "synecho"}
	rockBlockPubKey          = []byte(`-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlaWAVJfNWC4XfnRx96p9cztBcdQV6l8aKmzAlZdpEcQR6MSPzlgvihaUHNJgKm8t5ShR3jcDXIOI7er30cIN4/9aVFMe0LWZClUGgCSLc3rrMD4FzgOJ4ibD8scVyER/sirRzf5/dswJedEiMte1ElMQy2M6IWBACry9u12kIqG0HrhaQOzc6Tr8pHUWTKft3xwGpxCkV+K1N+9HCKFccbwb8okRP6FFAMm5sBbw4yAu39IVvcSL43Tucaa79FzOmfGs5mMvQfvO1ua7cOLKfAwkhxEjirC0/RYX7Wio5yL6jmykAHJqFG2HT0uyjjrQWMtoGgwv9cIcI7xbsDX6owIDAQAB
-----END PUBLIC KEY-----`)
)

// Start starts a webserver to process RockBLOCK messages received at /message
func Start(addr string) {
	http.HandleFunc("/health", handleHealthCheck)
	http.HandleFunc("/message", handleJSONRockBlockMessage(func(msg []byte) {
		log.Printf("message = %q\n", msg)
	}))
	http.ListenAndServe(addr, nil)
}

// Start starts a webserver to process RockBLOCK messages received at /message
func StartWithPrometheus(addr string, withTestData bool) {
	popCount = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "pipecyte_pop_total",
			Help: "Current population counts.",
		},
		[]string{"pop"},
	)

	if withTestData {
		go func() {
			for {
				log.Printf("adding 12 prochloro\n")
				popCount.WithLabelValues("prochloro").Add(12.0)
				time.Sleep(30 * time.Second)
			}
		}()
	}

	http.HandleFunc("/health", handleHealthCheck)
	http.HandleFunc("/message", handleJSONRockBlockMessage(messageCallback))
	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(addr, nil)
}

func handleHealthCheck(w http.ResponseWriter, req *http.Request) {
	log.Printf("new request from %v for %v\n", req.RemoteAddr, req.URL.Path)
	w.WriteHeader(http.StatusOK)
	w.Header().Set("Content-Type", "application/text")
	w.Write([]byte("healthy"))
}

func handleJSONRockBlockMessage(cb func([]byte)) func(w http.ResponseWriter, req *http.Request) {
	return func(w http.ResponseWriter, req *http.Request) {
		log.Printf("new request from %v for %v\n", req.RemoteAddr, req.URL.Path)
		body, err := io.ReadAll(req.Body)
		if err != nil {
			log.Printf("%v\n", err)
			return
		}

		var j JsonData
		err = json.NewDecoder(bytes.NewReader(body)).Decode(&j)
		if err != nil {
			log.Printf("could not decode JSON body: %v\n", err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		token, err := verifyToken([]byte(j.JWT))
		if err != nil {
			log.Println(err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusOK)

		msg, err := hex.DecodeString(token.Claims.(*MsgClaims).Data)
		if err != nil {
			log.Println(err)
			return
		}

		cb(msg)
	}
}

func messageCallback(msg []byte) {
	log.Printf("message = %q\n", msg)
	counts, err := countsFromMsg(msg)
	if err != nil || len(counts) != len(popNames) {
		log.Printf("bad message: %v\n", err)
		return
	}
	log.Printf("pop counts for %v are  %v\n", popNames, counts)
	for i, count := range counts {
		popCount.WithLabelValues(popNames[i]).Add(float64(count))
	}
}

func verifyToken(token []byte) (t *jwt.Token, err error) {
	// Trim trailing whitespace
	token = regexp.MustCompile(`\s*$`).ReplaceAll(token, []byte{})

	parsed, err := jwt.ParseWithClaims(string(token), &MsgClaims{}, func(t *jwt.Token) (interface{}, error) {
		key, err := jwt.ParseRSAPublicKeyFromPEM(rockBlockPubKey)
		if err != nil {
			return nil, err
		}
		return key, nil
	})
	if err != nil {
		return nil, err
	}

	if !parsed.Valid {
		return nil, fmt.Errorf("JWT is invalid")
	}
	return parsed, nil
}

func countsFromMsg(msg []byte) (counts []int, err error) {
	fields := strings.Split(string(msg), ",")
	for _, v := range fields {
		num, err := strconv.Atoi(v)
		if err != nil {
			return []int{}, err
		}
		counts = append(counts, num)
	}
	return counts, nil
}
