#include "esp_camera.h"
#include <WiFi.h>
#include <ArduinoWebsockets.h>

//
// WARNING!!! Make sure that you have either selected ESP32 Wrover Module,
//            or another board which has PSRAM enabled
//

// Select camera model
//#define CAMERA_MODEL_WROVER_KIT
//#define CAMERA_MODEL_ESP_EYE
//#define CAMERA_MODEL_M5STACK_PSRAM
//#define CAMERA_MODEL_M5STACK_WIDE
#define CAMERA_MODEL_AI_THINKER

#include "camera_pins.h"

const char* ssid = "ZTE B2017G";
const char* password = "isa201351379";
const char* websocket_server_host = "34.94.141.140";
const uint16_t websocket_server_port = 65080;
// Initiate stimulus pin definitions 
int rightStimPin = 12; // Define pin for right stimulus output 
int leftStimPin = 13; // Define pin for right stimulus output 
int rightState = LOW; // Initial state of right stimulus is LOW
int leftState = LOW; // Initial state of left stimulus is LOW 

// Initiate timing variables 
long previousTimeL = 0;        // will store last time stimulus was sent (LED was flashed)
unsigned long currentTimeL;
long previousTimeR = 0;
unsigned long currentTimeR; 
long interval = 1000;  // (milliseconds)

using namespace websockets;
WebsocketsClient client;

// Based on a given string, sets the appropriate GPIO to HIGH for stim_dur
void initStim(String msg){
  if(msg == "Right stimulus button activated"){
    Serial.println("Send right GPIO HIGH");
    previousTimeR = millis(); // Save the time the LED was turned on at 
    rightState = HIGH;
    digitalWrite(rightStimPin, HIGH);
  }else{
    Serial.println("Send left GPIO HIGH");
    previousTimeL = millis(); // Save the time the LED was turned on at 
    leftState = HIGH;
    digitalWrite(leftStimPin, HIGH);
  }
}

//void stimTimer(int pin, int state, long previousTime, unsigned long currentTime){
//  if((currentTime - previousTime > interval) && state == HIGH) {  
//    state = LOW;
//    Serial.println("turning left LED back off");
//    digitalWrite(pin, state);
//    return; 
//  }
//}

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 10000000; // 10MHz frequency
  config.pixel_format = PIXFORMAT_JPEG;

  // Set up output GPIOs for stimulus
//  pinMode(33, OUTPUT); // Integrated LED GPIO output LED 
  
  pinMode(rightStimPin, OUTPUT); // Right stimulus GPIO
  pinMode(leftStimPin, OUTPUT); // Left stimulus GPIO
  
  //init with high specs to pre-allocate larger buffers
  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA;
    config.jpeg_quality = 40;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }


  // camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

 
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");

  Serial.print("Camera Ready! Use 'http://");
  Serial.print(WiFi.localIP());
  Serial.println("' to connect");

  /////////////
  /// Websockets block 
  client.onMessage([](WebsocketsMessage msg){ 
      Serial.println("Got Message: " + msg.data());
      // Check for stimulus messages 
      if(msg.data() == "Right stimulus button activated" || msg.data()== "Left stimulus button activated"){ // If the message is stimulus message, call initStim
        initStim(msg.data());
      }
  });
  /////////////
  
  while(!client.connect(websocket_server_host, websocket_server_port, "/")){
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("Websocket Connected!");
}

void loop() { 
  /////////////
  /// Websockets block 
  client.poll();  /// Poll for messages from app 
  /////////////

  ///////////
  // Stimulus timing block
  
  currentTimeL = millis();
  currentTimeR = millis();
 
  if((currentTimeL - previousTimeL > interval) && leftState == HIGH) {  
    leftState = LOW;
    Serial.println("turning left LED back off");
    digitalWrite(leftStimPin, leftState);
  }
  if((currentTimeR - previousTimeR > interval) && rightState == HIGH) {  
    rightState = LOW;
    Serial.println("turning right LED back off");
    digitalWrite(rightStimPin, rightState);
  }
  /////////////
  
  camera_fb_t *fb = esp_camera_fb_get();
  if(!fb){
    Serial.println("Camera capture failed");
    esp_camera_fb_return(fb);
    return;
  }

  if(fb->format != PIXFORMAT_JPEG){
    Serial.println("Non-JPEG data not implemented");
    return;
  }

  client.sendBinary((const char*) fb->buf, fb->len);
  esp_camera_fb_return(fb);
}
