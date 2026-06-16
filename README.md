# Traffic Watch

An interactive, premium dark-themed web application that provides real-time access to live traffic camera feeds throughout the City of Calgary. Built with **React 19**, **Node.js/Express**, and **Leaflet**, the app aggregates and parses live geospatial data directly from the official City of Calgary Open Data API.

---

##  Features

*   **🗺️ Interactive Map View**: A dark-themed CartoDB map displaying all active traffic cameras across Calgary. Clicking a camera pin reveals its live image feed and information.
*   **🔍 Real-Time Search**: Instantly filter cameras by street names, intersections, or highway names.
*   **🧭 Quadrant Filtering**: Quickly pivot cameras based on Calgary's city quadrants: **NW**, **NE**, **SW**, and **SE**.
*   **⭐ Persistent Favorites**: Heart your frequently viewed cameras to save them to a dedicated "Favorites" tab. Favorites are persisted across sessions via local storage.
*   **🔄 Auto-Refresh Countdown**: Feeds automatically update every 30 seconds with an animated countdown indicator to ensure you see the most current traffic conditions.
*   **🔍 Full-Screen Lightbox**: Click any camera card to expand the live feed into an immersive full-screen modal view.
*   **📊 Dashboard Metrics**: High-level dashboard displays camera counts, favorite tallies, and quadrant distributions.
*   **⚡ Animated Skeleton Loaders**: Fluid image loading animations provide a modern, seamless user experience.

---

## 🛠️ Tech Stack

### Frontend
*   **React 19** (Functional Components, Hooks)
*   **Vite** (Next-generation frontend tooling)
*   **Leaflet & CartoDB Maps** (Interactive geospatial rendering using custom DivIcons)
*   **Vanilla CSS3** (Custom properties design system, glassmorphism, responsive grids)

### Backend
*   **Node.js & Express 5** (RESTful API proxying)
*   **Axios** (Server-to-API HTTP calls)
*   **Jest & Supertest** (API validation and test coverage)

---

## 🚀 Getting Started

### Prerequisites
Make sure you have [Node.js](https://nodejs.org/) (version 18+ recommended) installed on your machine.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/calgary-traffic-watch.git
    cd calgary-traffic-watch
    ```

2.  **Install project dependencies:**
    ```bash
    npm install
    ```

---

## 💻 Running the Application

To run the application, you need to start both the backend proxy server and the frontend Vite development server.

### 1. Start the Backend API Server
The backend handles API requests, filters out offline/invalid feeds, and reformats GeoJSON properties.
```bash
node server.js
