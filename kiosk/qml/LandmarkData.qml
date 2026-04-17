pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property var items: [
        {
            key: "namsan",
            name: "N-남산타워",
            nameEn: "N Seoul Tower",
            description: "서울의 중심인 남산 정상(해발 479m)에 위치한 높이 236.7m의 전파탑이자 전망대입니다. 세계적인 관광 명소로 거듭나고 있으며, 서울 시내 전역을 한눈에 조망할 수 있는 최적의 장소입니다.",
            history: "1969년 TV와 라디오 방송을 수도권에 송출하기 위한 종합 전파탑으로 건립되었습니다. 1980년부터 일반인에게 공개되었으며, 2005년 리모델링을 거쳐 현재의 'N서울타워'로 명칭을 변경했습니다.",
            distance: "2.3km",
            direction: "북동쪽 (NE)",
            altitude: "479m",
            thumbColor: "#1B4332"
        },
        {
            key: "lotte",
            name: "롯데월드타워",
            nameEn: "Lotte World Tower",
            description: "지상 123층, 높이 555m로 대한민국에서 가장 높은 건물이자 세계에서 5번째로 높은 마천루입니다. 한국의 전통적인 곡선미를 현대적으로 재해석한 디자인이 특징입니다.",
            history: "2010년 착공하여 2017년 개장했습니다. 최상층부의 '서울스카이' 전망대는 세계 최고 수준의 높이를 자랑하며, 쇼핑몰, 호텔, 오피스 등이 결합된 복합 문화 공간입니다.",
            distance: "8.1km",
            direction: "동쪽 (E)",
            altitude: "555m",
            thumbColor: "#14213D"
        },
        {
            key: "hangang",
            name: "한강대교",
            nameEn: "Hangang Bridge",
            description: "서울 용산구와 동작구를 잇는 한강 최초의 인도교입니다. 한강의 중심을 가로지르며 아름다운 야경과 함께 서울의 역사적인 교통 요충지 역할을 하고 있습니다.",
            history: "1917년 '한강 인도교'라는 이름으로 처음 개통되었습니다. 한국전쟁 당시 폭파되는 아픔을 겪었으나 1958년 복구되었고, 1982년 쌍둥이 아치교 형태로 확장되었습니다.",
            distance: "1.5km",
            direction: "남쪽 (S)",
            altitude: "",
            thumbColor: "#023E8A"
        },
        {
            key: "gyeongbok",
            name: "경복궁",
            nameEn: "Gyeongbokgung Palace",
            description: "조선 왕조의 제일 법궁(正宮)으로, 북악산을 배경으로 배산임수의 명당에 자리 잡고 있습니다. 근정전과 경회루 등 한국 전통 건축의 정수를 감상할 수 있는 국가적 문화유산입니다.",
            history: "1395년 태조 이성계에 의해 창건되었습니다. 임진왜란 당시 소실되었다가 1867년 흥선대원군에 의해 재건되었습니다. 현재까지도 원형 복원을 위한 정비 사업이 활발히 진행 중입니다.",
            distance: "4.2km",
            direction: "북쪽 (N)",
            altitude: "",
            thumbColor: "#3D405B"
        },
        {
            key: "sixty3",
            name: "63빌딩",
            nameEn: "63 SQUARE",
            description: "여의도의 상징적인 황금색 고층 빌딩입니다. 특수 코팅된 유리가 반사하는 황금빛 외관으로 유명하며, 수족관, 미술관 등 다양한 관람 시설을 갖춘 종합 엔터테인먼트 공간입니다.",
            history: "1985년 완공 당시 아시아에서 가장 높은 빌딩이었습니다. 1988년 서울 올림픽과 함께 대한민국의 고도성장을 상징하는 랜드마크로 자리 잡았습니다.",
            distance: "5.7km",
            direction: "남서쪽 (SW)",
            altitude: "249m",
            thumbColor: "#1A1A2E"
        },
        {
            key: "bukhan",
            name: "북한산",
            nameEn: "Bukhansan National Park",
            description: "서울 북부와 경기도에 걸쳐 있는 산으로, 세계적으로 드문 도심 속 국립공원입니다. 백운대, 인수봉 등 거대한 화강암 봉우리들이 웅장한 경관을 자아냅니다.",
            history: "삼국시대부터 전략적 요충지로 중요하게 여겨졌으며, 조선 시대에는 도성을 지키는 천혜의 요새로 북한산성이 축조되었습니다. 1983년에 국립공원으로 지정되었습니다.",
            distance: "9.3km",
            direction: "북쪽 (N)",
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
