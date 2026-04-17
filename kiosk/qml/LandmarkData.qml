pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property var items: [
        {
            key: "namsan",
            name: "Namsan Tower",
            nameEn: "N Seoul Tower",
            description: "Seoul's iconic landmark offering panoramic views of the city. The tower sits atop Namsan Mountain at 236m elevation, serving as both a broadcasting tower and major tourist attraction.",
            history: "Built in 1969 as a broadcasting tower, it was opened to the public in 1980 and has since become one of Seoul's most visited landmarks.",
            distance: "2.3km",
            direction: "Northeast",
            altitude: "236m",
            thumbColor: "#1B4332"
        },
        {
            key: "lotte",
            name: "Lotte World Tower",
            nameEn: "Lotte World Tower",
            description: "Standing at 555m, this supertall skyscraper is the tallest building in South Korea and the fifth tallest in the world. It houses an observation deck, hotel, offices, and shopping complex.",
            history: "Construction began in 2011 and was completed in 2017. The Seoul Sky observation deck on floors 117-123 offers breathtaking views.",
            distance: "8.1km",
            direction: "East",
            altitude: "555m",
            thumbColor: "#14213D"
        },
        {
            key: "hangang",
            name: "Hangang Bridge",
            nameEn: "Hangang Bridge",
            description: "A major bridge crossing the Han River, connecting Yongsan-gu and Dongjak-gu districts. It holds historical significance as the first pedestrian bridge over the Han River.",
            history: "Originally opened in 1917 as a pedestrian bridge, it was destroyed during the Korean War and rebuilt in 1958.",
            distance: "1.5km",
            direction: "South",
            altitude: "",
            thumbColor: "#023E8A"
        },
        {
            key: "gyeongbok",
            name: "Gyeongbokgung",
            nameEn: "Gyeongbokgung Palace",
            description: "The main royal palace of the Joseon dynasty, spreading across a vast ceremonial courtyard with Geunjeongjeon throne hall at its heart and Bukhansan framing the northern horizon.",
            history: "Originally built in 1395 by King Taejo, burned during the Imjin War in 1592, and painstakingly reconstructed starting in 1867. Ongoing restoration work continues today to recover structures lost under colonial rule.",
            distance: "4.2km",
            direction: "North",
            altitude: "",
            thumbColor: "#3D405B"
        },
        {
            key: "sixty3",
            name: "63 Building",
            nameEn: "63 SQUARE",
            description: "Iconic golden-hued skyscraper on Yeouido Island, still a defining silhouette of Seoul's skyline with an aquarium, art gallery, and observation deck on its upper floors.",
            history: "Completed in 1985 for the 1988 Seoul Olympics, it was the tallest building outside North America at the time and remained Korea's tallest for nearly two decades.",
            distance: "5.7km",
            direction: "Southwest",
            altitude: "250m",
            thumbColor: "#1A1A2E"
        },
        {
            key: "bukhan",
            name: "Bukhansan",
            nameEn: "Bukhansan National Park",
            description: "Rugged granite peaks rising above Seoul's northern edge, with trails winding through pine forests, hidden temples, and panoramic ridgelines overlooking the city.",
            history: "Designated a national park in 1983. Buddhist monks and scholars have practiced in its valleys since the Silla period more than a thousand years ago.",
            distance: "9.3km",
            direction: "North",
            altitude: "836m",
            thumbColor: "#264653"
        }
    ]

    function get(key) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].key === key) return items[i];
        }
        return null;
    }

    function heroImage(key) {
        return Theme.assetsUrl.length > 0
            ? Theme.assetsUrl + "/landmarks/" + key + "/hero.jpg"
            : "";
    }

    function thumbImage(key) {
        return Theme.assetsUrl.length > 0
            ? Theme.assetsUrl + "/landmarks/" + key + "/thumb.jpg"
            : "";
    }

    function nightImage(key) {
        return Theme.assetsUrl.length > 0
            ? Theme.assetsUrl + "/landmarks/" + key + "/night.jpg"
            : "";
    }
}
