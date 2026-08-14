import Foundation

// MARK: - Croatian Region Data

struct CroatianRegion: Identifiable, Hashable {
    let id: String
    let name: String
    let places: [String]
}

enum CroatianRegions {

    static let all: [CroatianRegion] = [
        otokKrk,
        rijekaIOkolica,
        crikvenickaRivijera,
        opatijaIOkolica,
        istra
    ]

    // MARK: Otok Krk
    static let otokKrk = CroatianRegion(
        id: "otok_krk",
        name: "Otok Krk",
        places: [
            "Krk",
            "Baška",
            "Punat",
            "Malinska",
            "Njivice",
            "Omišalj",
            "Vrbnik",
            "Dobrinj",
            "Šilo",
            "Klimno",
            "Soline",
            "Pinezići",
            "Vrh",
            "Kornić",
            "Linardići",
            "Brzac",
            "Skrbčići",
            "Muraj",
            "Jurandvor",
            "Batomalj",
            "Draga Bašćanska",
            "Garica",
            "Risika",
            "Krk (grad)",
            "Sv. Ivan Dobrinjski",
            "Čižići",
            "Kras",
            "Polje",
            "Nenadići"
        ]
    )

    // MARK: Rijeka i okolica
    static let rijekaIOkolica = CroatianRegion(
        id: "rijeka_i_okolica",
        name: "Rijeka i okolica",
        places: [
            // Gradske četvrti Rijeke
            "Centar",
            "Trsat",
            "Gornja Vežica",
            "Donja Vežica",
            "Krnjevo",
            "Sušak",
            "Zamet",
            "Martinkovac",
            "Turnić",
            "Pećine",
            "Kozala",
            "Bulevard",
            "Brajda",
            "Vojak",
            "Pulac",
            "Gornji Zamet",
            "Donji Zamet",
            "Kantrida",
            "Sveti Križ",
            "Rujevica",
            "Draga",
            "Drenova",
            "Podmurvice",
            "Gornja Drenova",
            "Orehovica",
            "Škurinje",
            "Gornje Škurinje",
            "Donje Škurinje",
            "Sveti Nikola",
            "Mihačeva Draga",
            // Okolica
            "Viškovo",
            "Kastav",
            "Čavle",
            "Jelenje",
            "Grobnik",
            "Kostrena",
            "Bakar",
            "Kraljevica",
            "Hreljin",
            "Kukuljanovo",
            "Cernik",
            "Marinići",
            "Marčelji",
            "Šmrika",
            "Krasica",
            "Praputnjak",
            "Podhum",
            "Gornja Jelušina",
            "Donja Jelušina",
            "Pesja",
            "Zoretići",
            "Kosi",
            "Jušići",
            "Pehlin"
        ]
    )

    // MARK: Crikvenička rivijera
    static let crikvenickaRivijera = CroatianRegion(
        id: "crikvenicka_rivijera",
        name: "Crikvenička rivijera",
        places: [
            "Crikvenica",
            "Selce",
            "Dramalj",
            "Jadranovo",
            "Novi Vinodolski",
            "Povile",
            "Klenovica",
            "Bribir",
            "Grižane",
            "Belgrad",
            "Vinodol",
            "Tribalj",
            "Smokovo",
            "Zagori",
            "Drivenik",
            "Kotor",
            "Ledenice",
            "Šmrika (Vinodolska)",
            "Kamenjak",
            "Zvirići",
            "Podgora",
            "Crkvišće"
        ]
    )

    // MARK: Opatija i okolica
    static let opatijaIOkolica = CroatianRegion(
        id: "opatija_i_okolica",
        name: "Opatija i okolica",
        places: [
            "Opatija",
            "Volosko",
            "Ičići",
            "Ika",
            "Lovran",
            "Medveja",
            "Mošćenička Draga",
            "Mošćenice",
            "Brseč",
            "Veprinac",
            "Pobri",
            "Matulji",
            "Jušići (Matulji)",
            "Mihotići",
            "Rukavac",
            "Zvoneća",
            "Bregi",
            "Pasjak",
            "Permani",
            "Jurdani",
            "Rupa",
            "Brdce",
            "Dobreć",
            "Klana",
            "Studena",
            "Škalnica"
        ]
    )

    // MARK: Istra
    static let istra = CroatianRegion(
        id: "istra",
        name: "Istra",
        places: [
            "Pula",
            "Rovinj",
            "Poreč",
            "Umag",
            "Novigrad",
            "Pazin",
            "Labin",
            "Rabac",
            "Vodnjan",
            "Bale",
            "Buje",
            "Buzet",
            "Grožnjan",
            "Motovun",
            "Oprtalj",
            "Sveti Lovreč",
            "Sveti Petar u Šumi",
            "Tinjan",
            "Cerovlje",
            "Lupoglav",
            "Lanišće",
            "Karojba",
            "Kanfanar",
            "Žminj",
            "Svetvinčenat",
            "Barban",
            "Marčana",
            "Ližnjan",
            "Medulin",
            "Premantura",
            "Fažana",
            "Peroj",
            "Galižana",
            "Plomin",
            "Kršan",
            "Nedešćina",
            "Čepić",
            "Pićan",
            "Sveta Nedelja",
            "Višnjan",
            "Tar",
            "Funtana",
            "Vrsar",
            "Sveti Ivan",
            "Červar Porat",
            "Kaštel (Buje)",
            "Momjan",
            "Brtonigla",
            "Završje",
            "Dragučevo",
            "Lovreč Pazenatički",
            "Kringa",
            "Dvigrad",
            "Baldaši",
            "Montižana",
            "Trviž"
        ]
    )
}
