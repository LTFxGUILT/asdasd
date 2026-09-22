--========================================================--
-- Zex
--========================================================--

--!native
--!optimize 2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local MaterialService = game:GetService("MaterialService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--========================================================--
-- MODULE LOADER
--========================================================--

local ModuleCache = {}

local function LoadModule(Path)
    if ModuleCache[Path] ~= nil then return ModuleCache[Path] end
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://cats-cure-depression.vercel.app/" .. Path))()
    end)
    if success then
        ModuleCache[Path] = result
        return result
    end
    return nil
end

local Library = LoadModule("moehack.net/interface/library.luau")
local SaveManager = LoadModule("moehack.net/interface/addons/SaveManager.lua")
local ThemeManager = LoadModule("moehack.net/interface/addons/ThemeManager.lua")

local Toggles = {}
local function AddToggle(box, flag, options)
    local toggle = box:AddToggle(flag, options)
    Toggles[flag] = toggle
    return toggle
end

local Visuals = LoadModule("moehack.net/modules/visuals.luau")
local Misc = LoadModule("moehack.net/modules/misc.luau")
local Desync = LoadModule("moehack.net/modules/desync.luau")

--========================================================--
-- GAME DETECTION
--========================================================--

local PlaceId = game.PlaceId
local PlaceName = "Unknown"
pcall(function()
    local info = MarketplaceService:GetProductInfo(PlaceId)
    if info and info.Name then PlaceName = info.Name end
end)
local IsBugFixes = PlaceId == 100971017807798

--========================================================--
-- FULL SKYBOX LIST
--========================================================--

local SkyboxList = {
    ["Default"] = nil,
    ["Airplane"] = { SkyboxBk = "rbxassetid://73547108795893", SkyboxDn = "rbxassetid://122241126103886", SkyboxFt = "rbxassetid://87314139945699", SkyboxLf = "rbxassetid://131857449903826", SkyboxRt = "rbxassetid://95648702676347", SkyboxUp = "rbxassetid://129898148846043" },
    ["Advertisement"] = { SkyboxBk = "rbxassetid://138692893170619", SkyboxDn = "rbxassetid://123078948090248", SkyboxFt = "rbxassetid://123241148900691", SkyboxLf = "rbxassetid://124438096063535", SkyboxRt = "rbxassetid://126777223324092", SkyboxUp = "rbxassetid://90048584143567" },
    ["Aurora"] = { SkyboxBk = "rbxassetid://138339126956203", SkyboxDn = "rbxassetid://113903959926304", SkyboxFt = "rbxassetid://103264780980881", SkyboxLf = "rbxassetid://137834626820195", SkyboxRt = "rbxassetid://82538510612472", SkyboxUp = "rbxassetid://107905968376682" },
    ["Beautiful"] = { SkyboxBk = "rbxassetid://90736047582767", SkyboxDn = "rbxassetid://119396381142553", SkyboxFt = "rbxassetid://123358130960817", SkyboxLf = "rbxassetid://125352194671071", SkyboxRt = "rbxassetid://101635202526354", SkyboxUp = "rbxassetid://124538804693477" },
    ["Black White & Red"] = { SkyboxBk = "rbxassetid://83765687709522", SkyboxDn = "rbxassetid://120483109298510", SkyboxFt = "rbxassetid://76200520436775", SkyboxLf = "rbxassetid://82066365625000", SkyboxRt = "rbxassetid://135705237471434", SkyboxUp = "rbxassetid://86779192968886" },
    ["Blackhole"] = { SkyboxBk = "rbxassetid://114879526955865", SkyboxDn = "rbxassetid://115608425504889", SkyboxFt = "rbxassetid://105210231479593", SkyboxLf = "rbxassetid://130786932020388", SkyboxRt = "rbxassetid://93149692440823", SkyboxUp = "rbxassetid://109644311648647" },
    ["Blue"] = { SkyboxBk = "rbxassetid://82181201196075", SkyboxDn = "rbxassetid://106139373130861", SkyboxFt = "rbxassetid://112657506632434", SkyboxLf = "rbxassetid://130672526775916", SkyboxRt = "rbxassetid://82733718502295", SkyboxUp = "rbxassetid://76130789111172" },
    ["Blue 2"] = { SkyboxBk = "rbxassetid://129017701457610", SkyboxDn = "rbxassetid://72952227775873", SkyboxFt = "rbxassetid://83388180217777", SkyboxLf = "rbxassetid://110616665386257", SkyboxRt = "rbxassetid://79856473634952", SkyboxUp = "rbxassetid://110140398045573" },
    ["Broken Sky"] = { SkyboxBk = "rbxassetid://81628786008541", SkyboxDn = "rbxassetid://87091408089650", SkyboxFt = "rbxassetid://131634356881212", SkyboxLf = "rbxassetid://103830018782494", SkyboxRt = "rbxassetid://90294952977934", SkyboxUp = "rbxassetid://119398861591687" },
    ["Chill Gray"] = { SkyboxBk = "rbxassetid://93835356175299", SkyboxDn = "rbxassetid://124313541577723", SkyboxFt = "rbxassetid://135070042914730", SkyboxLf = "rbxassetid://93985108616528", SkyboxRt = "rbxassetid://78988353701881", SkyboxUp = "rbxassetid://111665514165992" },
    ["Chill pink"] = { SkyboxBk = "rbxassetid://85596947678758", SkyboxDn = "rbxassetid://103772925919165", SkyboxFt = "rbxassetid://118391720986211", SkyboxLf = "rbxassetid://78620326249807", SkyboxRt = "rbxassetid://134108375345445", SkyboxUp = "rbxassetid://74761989159691" },
    ["Chroma Key"] = { SkyboxBk = "rbxassetid://100286539772977", SkyboxDn = "rbxassetid://100286539772977", SkyboxFt = "rbxassetid://100286539772977", SkyboxLf = "rbxassetid://100286539772977", SkyboxRt = "rbxassetid://100286539772977", SkyboxUp = "rbxassetid://100286539772977" },
    ["Cyan"] = { SkyboxBk = "rbxassetid://80837184684047", SkyboxDn = "rbxassetid://73325181662375", SkyboxFt = "rbxassetid://73440579889658", SkyboxLf = "rbxassetid://95456214807645", SkyboxRt = "rbxassetid://111266007355360", SkyboxUp = "rbxassetid://82123217422947" },
    ["Cirno"] = { SkyboxBk = "rbxassetid://74762296526939", SkyboxDn = "rbxassetid://111623638290317", SkyboxFt = "rbxassetid://92790595419735", SkyboxLf = "rbxassetid://86903319097192", SkyboxRt = "rbxassetid://134674857462994", SkyboxUp = "rbxassetid://138590351759988" },
    ["Damascus"] = { SkyboxBk = "rbxassetid://137207873984129", SkyboxDn = "rbxassetid://135790688389948", SkyboxFt = "rbxassetid://133534703223319", SkyboxLf = "rbxassetid://96147833182758", SkyboxRt = "rbxassetid://115053439750900", SkyboxUp = "rbxassetid://79506166155568" },
    ["Emo"] = { SkyboxBk = "rbxassetid://98311426633619", SkyboxDn = "rbxassetid://95754954109535", SkyboxFt = "rbxassetid://99006656516210", SkyboxLf = "rbxassetid://104775611046454", SkyboxRt = "rbxassetid://125620815192429", SkyboxUp = "rbxassetid://83308078386793" },
    ["Forest"] = { SkyboxBk = "rbxassetid://80901901709952", SkyboxDn = "rbxassetid://74939712249664", SkyboxFt = "rbxassetid://133999559479292", SkyboxLf = "rbxassetid://136202576980921", SkyboxRt = "rbxassetid://136766624463891", SkyboxUp = "rbxassetid://110322446125229" },
    ["Glungus"] = { SkyboxBk = "rbxassetid://120088843073635", SkyboxDn = "rbxassetid://130487592425379", SkyboxFt = "rbxassetid://122684149011174", SkyboxLf = "rbxassetid://121517928864617", SkyboxRt = "rbxassetid://128673436436405", SkyboxUp = "rbxassetid://94016010490330" },
    ["Goodnight"] = { SkyboxBk = "rbxassetid://93590148140827", SkyboxDn = "rbxassetid://102453743082771", SkyboxFt = "rbxassetid://118903490011578", SkyboxLf = "rbxassetid://126562643473125", SkyboxRt = "rbxassetid://77446329776959", SkyboxUp = "rbxassetid://120495452755285" },
    ["Green"] = { SkyboxBk = "rbxassetid://115264368956399", SkyboxDn = "rbxassetid://71354952700666", SkyboxFt = "rbxassetid://97012270262609", SkyboxLf = "rbxassetid://108153789386014", SkyboxRt = "rbxassetid://138977070344645", SkyboxUp = "rbxassetid://128592835484394" },
    ["GMS"] = { SkyboxBk = "rbxassetid://122583318800143", SkyboxDn = "rbxassetid://90814115556867", SkyboxFt = "rbxassetid://87827624355920", SkyboxLf = "rbxassetid://75671660263686", SkyboxRt = "rbxassetid://92860891552128", SkyboxUp = "rbxassetid://132666338666833" },
    ["Hades"] = { SkyboxBk = "rbxassetid://109091965359488", SkyboxDn = "rbxassetid://105055639105391", SkyboxFt = "rbxassetid://123142343765338", SkyboxLf = "rbxassetid://108686550118324", SkyboxRt = "rbxassetid://111787691336626", SkyboxUp = "rbxassetid://130767374376301" },
    ["Hazy"] = { SkyboxBk = "rbxassetid://103910387093354", SkyboxDn = "rbxassetid://117435385808509", SkyboxFt = "rbxassetid://82474848638554", SkyboxLf = "rbxassetid://111467674320984", SkyboxRt = "rbxassetid://101359280855053", SkyboxUp = "rbxassetid://79260041811201" },
    ["Horizon"] = { SkyboxBk = "rbxassetid://84472194532880", SkyboxDn = "rbxassetid://81421570215287", SkyboxFt = "rbxassetid://122294067632646", SkyboxLf = "rbxassetid://80093296558373", SkyboxRt = "rbxassetid://106132165831872", SkyboxUp = "rbxassetid://79853361901486" },
    ["Horizontal"] = { SkyboxBk = "rbxassetid://95393488001564", SkyboxDn = "rbxassetid://84045592084706", SkyboxFt = "rbxassetid://80202755446662", SkyboxLf = "rbxassetid://74682807483960", SkyboxRt = "rbxassetid://118187348480699", SkyboxUp = "rbxassetid://92293952820736" },
    ["Interbox"] = { SkyboxBk = "rbxassetid://74875250804271", SkyboxDn = "rbxassetid://94560677607401", SkyboxFt = "rbxassetid://127382829019931", SkyboxLf = "rbxassetid://106571255279226", SkyboxRt = "rbxassetid://99871256788841", SkyboxUp = "rbxassetid://73397616331209" },
    ["Light Blue"] = { SkyboxBk = "rbxassetid://122727678920298", SkyboxDn = "rbxassetid://109230667425614", SkyboxFt = "rbxassetid://86616045749204", SkyboxLf = "rbxassetid://97737748191700", SkyboxRt = "rbxassetid://114563499690902", SkyboxUp = "rbxassetid://130813351478114" },
    ["Light pink"] = { SkyboxBk = "rbxassetid://95476468795939", SkyboxDn = "rbxassetid://76714181333169", SkyboxFt = "rbxassetid://115429857888541", SkyboxLf = "rbxassetid://86026430610639", SkyboxRt = "rbxassetid://80186695497255", SkyboxUp = "rbxassetid://100349603600606" },
    ["Moonlight"] = { SkyboxBk = "rbxassetid://91969695428358", SkyboxDn = "rbxassetid://125883182632455", SkyboxFt = "rbxassetid://81367349924480", SkyboxLf = "rbxassetid://120849446017845", SkyboxRt = "rbxassetid://131627315382597", SkyboxUp = "rbxassetid://113053042424586" },
    ["Neon Sky 1"] = { SkyboxBk = "rbxassetid://109465370626009", SkyboxDn = "rbxassetid://92711396893206", SkyboxFt = "rbxassetid://104959308566115", SkyboxLf = "rbxassetid://73559393414345", SkyboxRt = "rbxassetid://124115400528691", SkyboxUp = "rbxassetid://89460814686454" },
    ["Neon Sky 2"] = { SkyboxBk = "rbxassetid://93698222156765", SkyboxDn = "rbxassetid://82071599862970", SkyboxFt = "rbxassetid://92192695079999", SkyboxLf = "rbxassetid://133706342652156", SkyboxRt = "rbxassetid://87786051107342", SkyboxUp = "rbxassetid://105821520001788" },
    ["Nesas"] = { SkyboxBk = "rbxassetid://133544697264542", SkyboxDn = "rbxassetid://79161176449168", SkyboxFt = "rbxassetid://129610708718668", SkyboxLf = "rbxassetid://91336600998609", SkyboxRt = "rbxassetid://134019086438106", SkyboxUp = "rbxassetid://112164003040620" },
    ["Night"] = { SkyboxBk = "rbxassetid://100918508547013", SkyboxDn = "rbxassetid://139263729429955", SkyboxFt = "rbxassetid://80826733640195", SkyboxLf = "rbxassetid://114584452759880", SkyboxRt = "rbxassetid://117619973765121", SkyboxUp = "rbxassetid://119947851059800" },
    ["Oblivion"] = { SkyboxBk = "rbxassetid://126028495725620", SkyboxDn = "rbxassetid://115653209517145", SkyboxFt = "rbxassetid://72081151330095", SkyboxLf = "rbxassetid://130105475564026", SkyboxRt = "rbxassetid://83881714922296", SkyboxUp = "rbxassetid://130573285946564" },
    ["Orange"] = { SkyboxBk = "rbxassetid://94455545393770", SkyboxDn = "rbxassetid://136060731252737", SkyboxFt = "rbxassetid://105179817185957", SkyboxLf = "rbxassetid://117888206872392", SkyboxRt = "rbxassetid://72593360761022", SkyboxUp = "rbxassetid://137051982472983" },
    ["Overcast"] = { SkyboxBk = "rbxassetid://104492444422288", SkyboxDn = "rbxassetid://119285770695744", SkyboxFt = "rbxassetid://103366247949453", SkyboxLf = "rbxassetid://93011517808079", SkyboxRt = "rbxassetid://127582448480235", SkyboxUp = "rbxassetid://73127053819001" },
    ["Pandora"] = { SkyboxBk = "rbxassetid://128999647577261", SkyboxDn = "rbxassetid://88223579632584", SkyboxFt = "rbxassetid://125141801502518", SkyboxLf = "rbxassetid://118941415742917", SkyboxRt = "rbxassetid://94820592501019", SkyboxUp = "rbxassetid://100494654244360" },
    ["Philly"] = { SkyboxBk = "rbxassetid://125196105176766", SkyboxDn = "rbxassetid://81181692218641", SkyboxFt = "rbxassetid://73976126621894", SkyboxLf = "rbxassetid://104714173442338", SkyboxRt = "rbxassetid://86553940604133", SkyboxUp = "rbxassetid://122849628658835" },
    ["Pink Sunrise"] = { SkyboxBk = "rbxassetid://72832903377294", SkyboxDn = "rbxassetid://115148441960861", SkyboxFt = "rbxassetid://89730892670751", SkyboxLf = "rbxassetid://116914445840077", SkyboxRt = "rbxassetid://87100974701616", SkyboxUp = "rbxassetid://104333511103999" },
    ["posterized"] = { SkyboxBk = "rbxassetid://84310783449353", SkyboxDn = "rbxassetid://107715454631524", SkyboxFt = "rbxassetid://132688267285334", SkyboxLf = "rbxassetid://72886548499200", SkyboxRt = "rbxassetid://90631442037943", SkyboxUp = "rbxassetid://109637462578776" },
    ["Purple"] = { SkyboxBk = "rbxassetid://73924793697749", SkyboxDn = "rbxassetid://87284569628644", SkyboxFt = "rbxassetid://124466187110657", SkyboxLf = "rbxassetid://113289771202840", SkyboxRt = "rbxassetid://79480591606614", SkyboxUp = "rbxassetid://99896340950201" },
    ["Red"] = { SkyboxBk = "rbxassetid://131890888619756", SkyboxDn = "rbxassetid://75549741155739", SkyboxFt = "rbxassetid://77824426118323", SkyboxLf = "rbxassetid://88250840355335", SkyboxRt = "rbxassetid://113825475145843", SkyboxUp = "rbxassetid://106759841236337" },
    ["sky_sunset"] = { SkyboxBk = "rbxassetid://120846289752950", SkyboxDn = "rbxassetid://73797556775963", SkyboxFt = "rbxassetid://123480803318391", SkyboxLf = "rbxassetid://126438439084815", SkyboxRt = "rbxassetid://122422673300850", SkyboxUp = "rbxassetid://126620859905248" },
    ["Space Blue"] = { SkyboxBk = "rbxassetid://138949297889720", SkyboxDn = "rbxassetid://101096773572392", SkyboxFt = "rbxassetid://77877536633414", SkyboxLf = "rbxassetid://98421538459696", SkyboxRt = "rbxassetid://114743751047316", SkyboxUp = "rbxassetid://133302554132673" },
    ["Spooky"] = { SkyboxBk = "rbxassetid://137767578049676", SkyboxDn = "rbxassetid://92783501556295", SkyboxFt = "rbxassetid://127820451839412", SkyboxLf = "rbxassetid://128689960573345", SkyboxRt = "rbxassetid://125189702225721", SkyboxUp = "rbxassetid://101534028974944" },
    ["Sunflowers"] = { SkyboxBk = "rbxassetid://114956782857108", SkyboxDn = "rbxassetid://94053425947915", SkyboxFt = "rbxassetid://100012571508783", SkyboxLf = "rbxassetid://85470129538071", SkyboxRt = "rbxassetid://85590965977413", SkyboxUp = "rbxassetid://74755608854554" },
    ["Universe"] = { SkyboxBk = "rbxassetid://94602021212735", SkyboxDn = "rbxassetid://130621824646135", SkyboxFt = "rbxassetid://102694634144051", SkyboxLf = "rbxassetid://89074438766201", SkyboxRt = "rbxassetid://112088164887032", SkyboxUp = "rbxassetid://96535121158896" },
    ["Vaporwave"] = { SkyboxBk = "rbxassetid://94635086479420", SkyboxDn = "rbxassetid://137546678743168", SkyboxFt = "rbxassetid://121887944974615", SkyboxLf = "rbxassetid://122255845153746", SkyboxRt = "rbxassetid://86939623081900", SkyboxUp = "rbxassetid://132476747188812" },
    ["Violet Evergarden"] = { SkyboxBk = "rbxassetid://139632062874474", SkyboxDn = "rbxassetid://104631352602731", SkyboxFt = "rbxassetid://102987487127501", SkyboxLf = "rbxassetid://124842265226555", SkyboxRt = "rbxassetid://124585619669609", SkyboxUp = "rbxassetid://76010756002592" },
    ["Blackhole 2"] = { SkyboxBk = "rbxassetid://105104726180993", SkyboxDn = "rbxassetid://125385498309031", SkyboxFt = "rbxassetid://96646304114089", SkyboxLf = "rbxassetid://79774369796178", SkyboxRt = "rbxassetid://94799631964682", SkyboxUp = "rbxassetid://135317299999121" },
    ["Castle grounds"] = { SkyboxBk = "rbxassetid://106858358669110", SkyboxDn = "rbxassetid://93632771131165", SkyboxFt = "rbxassetid://117736793566323", SkyboxLf = "rbxassetid://105315390779121", SkyboxRt = "rbxassetid://107653257003735", SkyboxUp = "rbxassetid://128662709498326" },
    ["Clear Skies"] = { SkyboxBk = "rbxassetid://91378441610573", SkyboxDn = "rbxassetid://121441260035906", SkyboxFt = "rbxassetid://74886122748958", SkyboxLf = "rbxassetid://117113220227443", SkyboxRt = "rbxassetid://79679718030516", SkyboxUp = "rbxassetid://124668719664943" },
    ["RemRam"] = { SkyboxBk = "rbxassetid://140698359884757", SkyboxDn = "rbxassetid://89669974466703", SkyboxFt = "rbxassetid://78895063857740", SkyboxLf = "rbxassetid://73868069075396", SkyboxRt = "rbxassetid://134960804641719", SkyboxUp = "rbxassetid://107959472459772" },
    ["Yumeko"] = { SkyboxBk = "rbxassetid://96138743815101", SkyboxDn = "rbxassetid://91308691824988", SkyboxFt = "rbxassetid://91482460949668", SkyboxLf = "rbxassetid://104574418241444", SkyboxRt = "rbxassetid://96116896026017", SkyboxUp = "rbxassetid://113332486282213" },
    ["Dead Star Forest"] = { SkyboxBk = "rbxassetid://72121494535904", SkyboxDn = "rbxassetid://102319563262355", SkyboxFt = "rbxassetid://93826727932716", SkyboxLf = "rbxassetid://86642027225712", SkyboxRt = "rbxassetid://140006158090405", SkyboxUp = "rbxassetid://103869672702120" },
    ["Fade Blue Sky"] = { SkyboxBk = "rbxassetid://87984570756163", SkyboxDn = "rbxassetid://78909155342128", SkyboxFt = "rbxassetid://115631198065665", SkyboxLf = "rbxassetid://82248221339792", SkyboxRt = "rbxassetid://133457151245754", SkyboxUp = "rbxassetid://104160367997013" },
    ["Apple Gradient"] = { SkyboxBk = "rbxassetid://114316162230029", SkyboxDn = "rbxassetid://71319690884064", SkyboxFt = "rbxassetid://75960170499764", SkyboxLf = "rbxassetid://114968494499843", SkyboxRt = "rbxassetid://86790562570673", SkyboxUp = "rbxassetid://92791972941858" },
    ["Berry Lipstick Gradient"] = { SkyboxBk = "rbxassetid://79196761653594", SkyboxDn = "rbxassetid://80321112817083", SkyboxFt = "rbxassetid://118223392157940", SkyboxLf = "rbxassetid://120334333970024", SkyboxRt = "rbxassetid://129998283839856", SkyboxUp = "rbxassetid://70408433996509" },
    ["Blurple Gradient"] = { SkyboxBk = "rbxassetid://102439697727815", SkyboxDn = "rbxassetid://103990213828509", SkyboxFt = "rbxassetid://126280654077662", SkyboxLf = "rbxassetid://128393579043132", SkyboxRt = "rbxassetid://86752441357923", SkyboxUp = "rbxassetid://102520403260034" },
    ["Choco Mint Gradient"] = { SkyboxBk = "rbxassetid://71313620324169", SkyboxDn = "rbxassetid://94833387119930", SkyboxFt = "rbxassetid://95098437889469", SkyboxLf = "rbxassetid://98440836487445", SkyboxRt = "rbxassetid://77416364885967", SkyboxUp = "rbxassetid://133629276761591" },
    ["Coastal Algae Gradient"] = { SkyboxBk = "rbxassetid://140609974149093", SkyboxDn = "rbxassetid://90655817506060", SkyboxFt = "rbxassetid://117084508847233", SkyboxLf = "rbxassetid://116879269372035", SkyboxRt = "rbxassetid://137444001252666", SkyboxUp = "rbxassetid://106470609441332" },
    ["Mikgazer Gradient"] = { SkyboxBk = "rbxassetid://85947683456382", SkyboxDn = "rbxassetid://84084788134412", SkyboxFt = "rbxassetid://107417809363820", SkyboxLf = "rbxassetid://107699326421590", SkyboxRt = "rbxassetid://99070217979170", SkyboxUp = "rbxassetid://75837874309037" },
    ["Orange popsicle Gradient"] = { SkyboxBk = "rbxassetid://74920308154241", SkyboxDn = "rbxassetid://111981752203093", SkyboxFt = "rbxassetid://111745073803249", SkyboxLf = "rbxassetid://91415201556534", SkyboxRt = "rbxassetid://131783062746385", SkyboxUp = "rbxassetid://79677631663862" },
    ["Pastel Gradient"] = { SkyboxBk = "rbxassetid://125654369191644", SkyboxDn = "rbxassetid://108170615414134", SkyboxFt = "rbxassetid://136457589282129", SkyboxLf = "rbxassetid://121913813736100", SkyboxRt = "rbxassetid://109362483438496", SkyboxUp = "rbxassetid://137403625050828" },
    ["Rainbox Stripes"] = { SkyboxBk = "rbxassetid://93423351142638", SkyboxDn = "rbxassetid://113257233229801", SkyboxFt = "rbxassetid://115452038059644", SkyboxLf = "rbxassetid://120116367735014", SkyboxRt = "rbxassetid://120390283315496", SkyboxUp = "rbxassetid://114462467659070" },
    ["Strawberry Mint Gradient"] = { SkyboxBk = "rbxassetid://135101815200538", SkyboxDn = "rbxassetid://89556729827488", SkyboxFt = "rbxassetid://85684320506481", SkyboxLf = "rbxassetid://118239841658414", SkyboxRt = "rbxassetid://95133429619131", SkyboxUp = "rbxassetid://104258944832654" },
    ["Stripped socks blue"] = { SkyboxBk = "rbxassetid://77389289542594", SkyboxDn = "rbxassetid://130595937441966", SkyboxFt = "rbxassetid://86832821714939", SkyboxLf = "rbxassetid://74007610072670", SkyboxRt = "rbxassetid://136713694375460", SkyboxUp = "rbxassetid://81534633432338" },
    ["Stripped socks pink"] = { SkyboxBk = "rbxassetid://121738578328233", SkyboxDn = "rbxassetid://102474175368066", SkyboxFt = "rbxassetid://89409036280009", SkyboxLf = "rbxassetid://139239911630436", SkyboxRt = "rbxassetid://116934521995668", SkyboxUp = "rbxassetid://106946806395976" },
    ["Grimnight"] = { SkyboxBk = "rbxassetid://136556006511509", SkyboxDn = "rbxassetid://89856395371965", SkyboxFt = "rbxassetid://92650911238512", SkyboxLf = "rbxassetid://116850165173626", SkyboxRt = "rbxassetid://124882470605063", SkyboxUp = "rbxassetid://139856667307961" },
    ["Northern Lights"] = { SkyboxBk = "rbxassetid://127505217737327", SkyboxDn = "rbxassetid://116691368217061", SkyboxFt = "rbxassetid://81360225358665", SkyboxLf = "rbxassetid://119465362876475", SkyboxRt = "rbxassetid://71250101231083", SkyboxUp = "rbxassetid://89796518646675" },
    ["Peacefull Morning"] = { SkyboxBk = "rbxassetid://135005512523938", SkyboxDn = "rbxassetid://127662335423893", SkyboxFt = "rbxassetid://79378711980854", SkyboxLf = "rbxassetid://77482503353398", SkyboxRt = "rbxassetid://108981066645432", SkyboxUp = "rbxassetid://120552429016087" },
    ["Pumpkin Hill"] = { SkyboxBk = "rbxassetid://135005512523938", SkyboxDn = "rbxassetid://127662335423893", SkyboxFt = "rbxassetid://79378711980854", SkyboxLf = "rbxassetid://77482503353398", SkyboxRt = "rbxassetid://108981066645432", SkyboxUp = "rbxassetid://120552429016087" },
    ["Purple Nebula"] = { SkyboxBk = "rbxassetid://130889036503079", SkyboxDn = "rbxassetid://132469477304685", SkyboxFt = "rbxassetid://82899701930696", SkyboxLf = "rbxassetid://90989559107047", SkyboxRt = "rbxassetid://125811044267041", SkyboxUp = "rbxassetid://122890410169804" },
    ["Rocks 1"] = { SkyboxBk = "rbxassetid://102379564898452", SkyboxDn = "rbxassetid://139127629307981", SkyboxFt = "rbxassetid://101642650576342", SkyboxLf = "rbxassetid://116675331231534", SkyboxRt = "rbxassetid://75457312053318", SkyboxUp = "rbxassetid://129943505569790" },
    ["Rocks 2"] = { SkyboxBk = "rbxassetid://121381382784797", SkyboxDn = "rbxassetid://120505417722659", SkyboxFt = "rbxassetid://132575887335522", SkyboxLf = "rbxassetid://72176676283275", SkyboxRt = "rbxassetid://130624790311325", SkyboxUp = "rbxassetid://86909034168743" },
    ["Shiverfrost"] = { SkyboxBk = "rbxassetid://91437530334118", SkyboxDn = "rbxassetid://125132954905595", SkyboxFt = "rbxassetid://87700886149196", SkyboxLf = "rbxassetid://140533311428649", SkyboxRt = "rbxassetid://85260121078056", SkyboxUp = "rbxassetid://119992457840474" },
    ["Disaster"] = { SkyboxBk = "rbxassetid://70599573542684", SkyboxDn = "rbxassetid://85926817101179", SkyboxFt = "rbxassetid://92534720286142", SkyboxLf = "rbxassetid://105182129845985", SkyboxRt = "rbxassetid://106170214500482", SkyboxUp = "rbxassetid://94676913711931" },
    ["Nibiru_bl"] = { SkyboxBk = "rbxassetid://116640628388038", SkyboxDn = "rbxassetid://114966384634980", SkyboxFt = "rbxassetid://108800895441970", SkyboxLf = "rbxassetid://84910650412189", SkyboxRt = "rbxassetid://131615338667981", SkyboxUp = "rbxassetid://115031643846156" },
    ["Purple 2"] = { SkyboxBk = "rbxassetid://99243807606271", SkyboxDn = "rbxassetid://77171229773233", SkyboxFt = "rbxassetid://104812607308984", SkyboxLf = "rbxassetid://85403043887199", SkyboxRt = "rbxassetid://124976026726289", SkyboxUp = "rbxassetid://112216675963887" },
    ["Utter East"] = { SkyboxBk = "rbxassetid://135107644416383", SkyboxDn = "rbxassetid://89915599913546", SkyboxFt = "rbxassetid://100247274801351", SkyboxLf = "rbxassetid://106712826703279", SkyboxRt = "rbxassetid://114145369798978", SkyboxUp = "rbxassetid://117854984028729" },
    ["Whomp Fortress"] = { SkyboxBk = "rbxassetid://74425072943752", SkyboxDn = "rbxassetid://111071018695875", SkyboxFt = "rbxassetid://116612487359518", SkyboxLf = "rbxassetid://134560024286794", SkyboxRt = "rbxassetid://138489453144876", SkyboxUp = "rbxassetid://73930419982083" },
    ["Winterness"] = { SkyboxBk = "rbxassetid://132925977332520", SkyboxDn = "rbxassetid://81443080640995", SkyboxFt = "rbxassetid://131179843166733", SkyboxLf = "rbxassetid://133010053158683", SkyboxRt = "rbxassetid://88760737531208", SkyboxUp = "rbxassetid://114312644906946" },
    ["Whales"] = { SkyboxBk = "rbxassetid://108683039959071", SkyboxDn = "rbxassetid://91278785379378", SkyboxFt = "rbxassetid://105872825973301", SkyboxLf = "rbxassetid://84231018929136", SkyboxRt = "rbxassetid://137303937730114", SkyboxUp = "rbxassetid://94631685718406" },
    ["marisa_box"] = { SkyboxBk = "rbxassetid://130164010973325", SkyboxDn = "rbxassetid://88670515643916", SkyboxFt = "rbxassetid://115384279495120", SkyboxLf = "rbxassetid://110978567346125", SkyboxRt = "rbxassetid://115685472548919", SkyboxUp = "rbxassetid://81354409061919" },
    ["Rainbow Gradient"] = { SkyboxBk = "rbxassetid://73131331581182", SkyboxDn = "rbxassetid://83206077558158", SkyboxFt = "rbxassetid://92306149770480", SkyboxLf = "rbxassetid://115930128088191", SkyboxRt = "rbxassetid://77067806496664", SkyboxUp = "rbxassetid://126777959946135" },
    ["Red Fish"] = { SkyboxBk = "rbxassetid://126915339998994", SkyboxDn = "rbxassetid://116473958053203", SkyboxFt = "rbxassetid://91181413775637", SkyboxLf = "rbxassetid://98029475631582", SkyboxRt = "rbxassetid://128049640837803", SkyboxUp = "rbxassetid://128215567265710" },
    ["SFOTH"] = { SkyboxBk = "rbxassetid://132012116914536", SkyboxDn = "rbxassetid://138998248173409", SkyboxFt = "rbxassetid://106331975843829", SkyboxLf = "rbxassetid://136320632593472", SkyboxRt = "rbxassetid://96431537755214", SkyboxUp = "rbxassetid://127246185063616" },
    ["sky2006"] = { SkyboxBk = "rbxassetid://131328244549361", SkyboxDn = "rbxassetid://114203025178095", SkyboxFt = "rbxassetid://121596562960640", SkyboxLf = "rbxassetid://99805634761262", SkyboxRt = "rbxassetid://72645466580459", SkyboxUp = "rbxassetid://107818992094722" },
    ["Tenkobox"] = { SkyboxBk = "rbxassetid://70589196561590", SkyboxDn = "rbxassetid://131625458848417", SkyboxFt = "rbxassetid://116423396984358", SkyboxLf = "rbxassetid://110027809487856", SkyboxRt = "rbxassetid://102169073552538", SkyboxUp = "rbxassetid://96172937036606" },
    ["Underwater"] = { SkyboxBk = "rbxassetid://107220210166167", SkyboxDn = "rbxassetid://120331367598175", SkyboxFt = "rbxassetid://97335578412517", SkyboxLf = "rbxassetid://72020524872835", SkyboxRt = "rbxassetid://99966208838590", SkyboxUp = "rbxassetid://107673686685770" },
    ["Wackybox"] = { SkyboxBk = "rbxassetid://127187188135902", SkyboxDn = "rbxassetid://124437962019004", SkyboxFt = "rbxassetid://88070315672092", SkyboxLf = "rbxassetid://117513052037884", SkyboxRt = "rbxassetid://119561823338752", SkyboxUp = "rbxassetid://70807437403604" },
    ["Gradient 1"] = { SkyboxBk = "rbxassetid://135829586091603", SkyboxDn = "rbxassetid://86726757473186", SkyboxFt = "rbxassetid://73443123094514", SkyboxLf = "rbxassetid://138283866531131", SkyboxRt = "rbxassetid://71030252933255", SkyboxUp = "rbxassetid://114301643129799" },
    ["Gradient 2"] = { SkyboxBk = "rbxassetid://94371308274982", SkyboxDn = "rbxassetid://94358811210698", SkyboxFt = "rbxassetid://110895939419633", SkyboxLf = "rbxassetid://136132227777862", SkyboxRt = "rbxassetid://121564535990427", SkyboxUp = "rbxassetid://113607288706133" },
    ["Waterfall"] = { SkyboxBk = "rbxassetid://108222002838122", SkyboxDn = "rbxassetid://84671669495038", SkyboxFt = "rbxassetid://70490780507889", SkyboxLf = "rbxassetid://82639016420549", SkyboxRt = "rbxassetid://91033869259841", SkyboxUp = "rbxassetid://81625444695528" },
}

local SkyNames = {}
for name in pairs(SkyboxList) do table.insert(SkyNames, name) end
table.sort(SkyNames)

local currentSkybox = "Default"
local skyboxEnabled = false
local originalSky = nil

local function ApplySkybox(name)
    if not originalSky then
        local existing = Lighting:FindFirstChildOfClass("Sky")
        if existing then originalSky = existing:Clone() end
    end
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Sky") then child:Destroy() end
    end
    if name == "Default" or not skyboxEnabled then
        if originalSky then originalSky:Clone().Parent = Lighting end
        return
    end
    local data = SkyboxList[name]
    if not data then return end
    local sky = Instance.new("Sky")
    sky.Name = "CustomSky_" .. name
    for prop, value in pairs(data) do
        pcall(function() sky[prop] = value end)
    end
    sky.Parent = Lighting
end

--========================================================--
-- LIMB EXTENDER
--========================================================--

local LimbExtender
pcall(function()
    getgenv().le = getgenv().le or loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/scripts/refs/heads/main/LimbExtender.lua'))()
    LimbExtender = getgenv().le({
        LISTEN_FOR_INPUT = false, USE_HIGHLIGHT = false,
        ESP = false, ESP_BOX = false, ESP_TRACER = false,
        ESP_SKELETON = false, ESP_HEALTH = false, ESP_LABEL = false, CHAMS = false,
        TARGET_LIMB = "Head", LIMB_SIZE = 5
    })
end)

--========================================================--
-- STATE
--========================================================--

local noFallEnabled, cframeEnabled, lockFOV, rainbowBody, rainbowGun = false, false, false, false, false
local infiniteAmmo, headExpandEnabled, quickInteract, chamsEnabled = false, false, false, false
local cframeSpeed, currentFOV, headSize = 50, 70, 5
local charTransparency, charHue, rainbowBodySpeed = 0, 0, 0.008
local gunTransparency, gunHue, rainbowGunSpeed = 0, 0, 0.015
local fallConnection, originalPrompts = nil, {}
local ChamObjects = {}

local espEnabled, espBox, espBoxFill, espName, espDistance = false, false, false, false, false
local espHealthBar, espHealthText, espTool, espRenderTeam = false, false, false, false
local espBoxFillTransparency, espRenderDistance, espRenderHz = 0.5, 500, 60
local espBoxColor = Color3.fromRGB(255, 255, 255)
local espFillColor = Color3.fromRGB(255, 255, 255)
local espNameColor = Color3.fromRGB(255, 255, 255)
local espObjects, espAccumulator = {}, 0

local itemEspEnabled, showAccessories, showTools = false, true, true
local showWorkspaceOnly, showOnPlayers = false, true
local maxItemEspDistance, itemEspObjects, trackedItems = 500, {}, {}
local itemEspAccum, rainbowAccum = 0, 0

--========================================================--
-- TELEPORTS (improved)
--========================================================--

local function getPartCFrame(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.CFrame end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart.CFrame end
        local p = inst:FindFirstChildWhichIsA("BasePart", true)
        if p then return p.CFrame end
    end
    return nil
end

local function safeTeleport(cf, label)
    if not cf then
        print("[TP] Failed:", label or "unknown")
        return false
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        print("[TP] No character")
        return false
    end
    -- lift slightly so you don't clip into floor
    local target = cf + Vector3.new(0, 5, 0)
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = target
    end)
    print("[TP] →", label or "location")
    return true
end

local function tpToNamed(name, searchNames)
    for _, n in ipairs(searchNames or {name}) do
        local obj = Workspace:FindFirstChild(n, true)
        if obj then
            local cf = getPartCFrame(obj)
            if cf then return safeTeleport(cf, n) end
        end
    end
    print("[TP] Not found:", name)
    return false
end

-- Resolved locations (can expand when you send coords)
local TeleportLocations = {
    -- Safe / zones
    { Name = "Spawn", Find = {"SpawnLocation", "Spawn"} },
    { Name = "Shrine", Find = {"ShrineZone", "shrine"} },
    { Name = "Temple", Find = {"TempleZone"} },
    { Name = "Tea House", Find = {"TeaHouseZone", "Teahouse", "TeaHouse"} },
    { Name = "Dojo", Find = {"dojo", "Dojo"} },
}

-- Optional hard coords (fill these when you send them)
-- Format: { Name = "Label", CFrame = CFrame.new(x, y, z) }
local HardcodedTPs = {
    -- example: { Name = "Custom Spot", CFrame = CFrame.new(0, 50, 0) },
}

local function doTeleport(entry)
    if entry.CFrame then
        return safeTeleport(entry.CFrame, entry.Name)
    end
    return tpToNamed(entry.Name, entry.Find)
end

--========================================================--
-- ITEM ESP (optimized)
--========================================================--

local function clearItemESP()
    for _, data in pairs(itemEspObjects) do
        if data.billboard then pcall(function() data.billboard:Destroy() end) end
        if data.highlight then pcall(function() data.highlight:Destroy() end) end
    end
    table.clear(itemEspObjects)
end

local function isItem(obj)
    return obj:IsA("Accessory") or obj:IsA("Tool")
end

local function shouldShowItem(obj)
    if not obj or not obj.Parent then return false end
    if obj:IsA("Accessory") and not showAccessories then return false end
    if obj:IsA("Tool") and not showTools then return false end
    if not isItem(obj) then return false end
    local part = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and (part.Position - root.Position).Magnitude > maxItemEspDistance then return false end
    local onPlayer = false
    for _, plr in ipairs(Players:GetPlayers()) do
        if (plr.Character and obj:IsDescendantOf(plr.Character))
            or (plr:FindFirstChild("Backpack") and obj:IsDescendantOf(plr.Backpack)) then
            onPlayer = true
            break
        end
    end
    if showWorkspaceOnly and onPlayer then return false end
    if not showOnPlayers and onPlayer then return false end
    return true
end

local function createItemEsp(obj)
    if itemEspObjects[obj] then return end
    if not shouldShowItem(obj) then return end
    local part = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
    if not part then return end
    local data = {}
    local hl = Instance.new("Highlight")
    hl.Name = "ItemESP"
    hl.Adornee = obj
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = obj:IsA("Tool") and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(100, 200, 255)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.6
    hl.Parent = CoreGui
    data.highlight = hl
    local bb = Instance.new("BillboardGui")
    bb.Name = "ItemESP_BB"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 150, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = CoreGui
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = obj.Name .. "\n[" .. obj.ClassName .. "]"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.Parent = bb
    data.billboard = bb
    itemEspObjects[obj] = data
end

local function trackItem(obj)
    if isItem(obj) then trackedItems[obj] = true end
end

local function untrackItem(obj)
    trackedItems[obj] = nil
    local data = itemEspObjects[obj]
    if data then
        if data.billboard then pcall(function() data.billboard:Destroy() end) end
        if data.highlight then pcall(function() data.highlight:Destroy() end) end
        itemEspObjects[obj] = nil
    end
end

local function initialItemScan()
    table.clear(trackedItems)
    for _, obj in ipairs(Workspace:GetDescendants()) do trackItem(obj) end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            for _, obj in ipairs(plr.Character:GetChildren()) do trackItem(obj) end
        end
        local bp = plr:FindFirstChild("Backpack")
        if bp then for _, obj in ipairs(bp:GetChildren()) do trackItem(obj) end end
    end
end

Workspace.DescendantAdded:Connect(function(obj) if isItem(obj) then trackItem(obj) end end)
Workspace.DescendantRemoving:Connect(function(obj) if trackedItems[obj] then untrackItem(obj) end end)

local function updateItemESP()
    if not itemEspEnabled then clearItemESP() return end
    for obj in pairs(trackedItems) do
        if not obj.Parent then
            untrackItem(obj)
        elseif shouldShowItem(obj) then
            createItemEsp(obj)
        else
            local data = itemEspObjects[obj]
            if data then
                if data.billboard then pcall(function() data.billboard:Destroy() end) end
                if data.highlight then pcall(function() data.highlight:Destroy() end) end
                itemEspObjects[obj] = nil
            end
        end
    end
end

--========================================================--
-- PRAY
--========================================================--

local function fireGiveCrateItems(a1, a2, a3)
    local remote = ReplicatedStorage:FindFirstChild("GiveCrateItems")
    if not remote then print("[Pray] GiveCrateItems missing") return end
    pcall(function()
        if a3 ~= nil then remote:FireServer(a1, a2, a3)
        elseif a2 ~= nil then remote:FireServer(a1, a2)
        elseif a1 ~= nil then remote:FireServer(a1)
        else remote:FireServer() end
    end)
end

local function scanHonorEvents()
    local folder = ReplicatedStorage:FindFirstChild("HonorEvents")
    if not folder then print("[Pray] No HonorEvents") return end
    print("=== HonorEvents ===")
    for _, obj in ipairs(folder:GetDescendants()) do
        print(obj:GetFullName(), obj.ClassName)
    end
end

local function fireAllHonorRemotes()
    local folder = ReplicatedStorage:FindFirstChild("HonorEvents")
    if not folder then return end
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            pcall(function() obj:FireServer() end)
            pcall(function() obj:FireServer(LocalPlayer) end)
        elseif obj:IsA("RemoteFunction") then
            pcall(function() obj:InvokeServer() end)
        end
    end
end

local function tryPlayerToolEvents()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local function tryPath(root, path)
        local obj = root
        for part in string.gmatch(path, "[^%.]+") do
            if not obj then return end
            obj = obj:FindFirstChild(part)
        end
        if obj and (obj:IsA("RemoteEvent") or obj:IsA("BindableEvent")) then
            pcall(function() obj:FireServer() end)
        end
    end
    if backpack then tryPath(backpack, "katana.epicthing") end
    if char then tryPath(char, "bowcode.bow2") end
end

local function fullPrayAttempt()
    print("========== FULL PRAY ==========")
    doTeleport({ Name = "Shrine", Find = {"ShrineZone", "shrine"} })
    task.wait(0.25)
    fireGiveCrateItems()
    fireGiveCrateItems(LocalPlayer)
    fireGiveCrateItems(true)
    fireAllHonorRemotes()
    tryPlayerToolEvents()
    print("===============================")
end

--========================================================--
-- WINDOW
--========================================================--

local Window = Library:CreateWindow({
    Title = "Testing",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Zex = Window:AddTab("Zex"),
    ESP = Window:AddTab("ESP"),
    Visuals = Window:AddTab("Visuals"),
    Misc = Window:AddTab("Misc"),
    GameMods = Window:AddTab("Game Mods"),
    Settings = Window:AddTab("Settings"),
}

--========================================================--
-- ZEX
--========================================================--

local MovementBox = Tabs.Zex:AddLeftGroupbox("Movement")
MovementBox:AddToggle("NoFall", {
    Text = "No Fall Damage", Default = false,
    Callback = function(v)
        noFallEnabled = v
        if fallConnection then fallConnection:Disconnect(); fallConnection = nil end
        if v then
            fallConnection = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
                    if hum:GetState() == Enum.HumanoidStateType.Freefall then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end)
            end)
        end
    end
})
MovementBox:AddToggle("CFrameSpeed", { Text = "CFrame Speed", Default = false, Callback = function(v) cframeEnabled = v end })
MovementBox:AddSlider("CFrameSpeedValue", { Text = "CFrame Speed", Min = 10, Max = 150, Default = 50, Rounding = 0, Callback = function(v) cframeSpeed = v end })

local FOVBox = Tabs.Zex:AddRightGroupbox("FOV")
FOVBox:AddSlider("FOV", { Text = "FOV", Min = 30, Max = 120, Default = 70, Rounding = 0, Callback = function(v) currentFOV = v; pcall(function() Camera.FieldOfView = v end) end })
FOVBox:AddToggle("LockFOV", { Text = "Lock FOV", Default = false, Callback = function(v) lockFOV = v end })

local RainbowBox = Tabs.Zex:AddLeftGroupbox("Rainbow")
RainbowBox:AddToggle("RainbowBody", { Text = "Rainbow Body", Default = false, Callback = function(v) rainbowBody = v end })
RainbowBox:AddSlider("BodyTransparency", { Text = "Body Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Callback = function(v) charTransparency = v end })
RainbowBox:AddSlider("BodySpeed", { Text = "Body Speed", Min = 0.001, Max = 0.05, Default = 0.008, Rounding = 3, Callback = function(v) rainbowBodySpeed = v end })
RainbowBox:AddToggle("RainbowGun", { Text = "Rainbow Gun", Default = false, Callback = function(v) rainbowGun = v end })
RainbowBox:AddSlider("GunTransparency", { Text = "Gun Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Callback = function(v) gunTransparency = v end })
RainbowBox:AddSlider("GunSpeed", { Text = "Gun Speed", Min = 0.001, Max = 0.05, Default = 0.015, Rounding = 3, Callback = function(v) rainbowGunSpeed = v end })

local AmmoBox = Tabs.Zex:AddRightGroupbox("Ammo")
AmmoBox:AddToggle("InfiniteAmmo", { Text = "Infinite Ammo", Default = false, Callback = function(v) infiniteAmmo = v end })

local HeadBox = Tabs.Zex:AddRightGroupbox("Limb Extender")
HeadBox:AddToggle("HeadExpand", {
    Text = "Enabled", Default = false,
    Callback = function(v)
        headExpandEnabled = v
        if LimbExtender then
            pcall(function()
                if v then
                    LimbExtender:Set("TARGET_LIMB", "Head")
                    LimbExtender:Set("LIMB_SIZE", headSize)
                    LimbExtender:Start()
                else
                    LimbExtender:Stop()
                end
            end)
        end
    end
})
HeadBox:AddSlider("HeadSize", { Text = "Limb Size", Min = 5, Max = 50, Default = 5, Rounding = 0, Callback = function(v) headSize = v; if LimbExtender and headExpandEnabled then pcall(function() LimbExtender:Set("LIMB_SIZE", v) end) end end })
HeadBox:AddDropdown("TargetLimb", { Text = "Target Limb", Default = 1, Values = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, Callback = function(v) if LimbExtender and headExpandEnabled then pcall(function() LimbExtender:Set("TARGET_LIMB", v) end) end end })

local InteractBox = Tabs.Zex:AddLeftGroupbox("Interaction")
InteractBox:AddToggle("QuickInteract", {
    Text = "Quick Interact", Default = false,
    Callback = function(v)
        quickInteract = v
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                if v then
                    if not originalPrompts[obj] then
                        originalPrompts[obj] = { HoldDuration = obj.HoldDuration, RequiresLineOfSight = obj.RequiresLineOfSight }
                    end
                    pcall(function() obj.HoldDuration = 0; obj.RequiresLineOfSight = false end)
                else
                    local o = originalPrompts[obj]
                    if o then pcall(function() obj.HoldDuration = o.HoldDuration; obj.RequiresLineOfSight = o.RequiresLineOfSight end) end
                end
            end
        end
    end
})
workspace.DescendantAdded:Connect(function(obj)
    if quickInteract and obj:IsA("ProximityPrompt") then
        pcall(function() obj.HoldDuration = 0; obj.RequiresLineOfSight = false end)
    end
end)

local ChamsBox = Tabs.Zex:AddLeftGroupbox("Chams")
ChamsBox:AddToggle("SimpleChams", {
    Text = "Simple Chams", Default = false,
    Callback = function(v)
        chamsEnabled = v
        if not v then
            for _, hl in pairs(ChamObjects) do if hl then pcall(function() hl:Destroy() end) end end
            ChamObjects = {}
        end
    end
})

--========================================================--
-- ESP (Players)
--========================================================--

local function RemoveESP(player)
    local data = espObjects[player]
    if not data then return end
    for _, object in pairs(data) do
        if typeof(object) == "Instance" then pcall(function() object:Destroy() end) end
    end
    espObjects[player] = nil
end

local function CreateESP(player)
    if player == LocalPlayer or espObjects[player] then return end
    local data = {}
    local highlight = Instance.new("Highlight")
    highlight.Name = "ZexESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = espFillColor
    highlight.OutlineColor = espBoxColor
    highlight.FillTransparency = 0.5
    highlight.Enabled = false
    highlight.Parent = CoreGui
    data.Highlight = highlight
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ZexESPInfo"
    billboard.Size = UDim2.new(0, 220, 0, 100)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.Parent = CoreGui
    data.Billboard = billboard
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.Code
    text.TextSize = 13
    text.TextStrokeTransparency = 0
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.Parent = billboard
    data.Text = text
    espObjects[player] = data
end

local function UpdatePlayerESP(player)
    if player == LocalPlayer then return end
    local data = espObjects[player]
    if not espEnabled then
        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end
        return
    end
    local character = player.Character
    if not character then
        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    if not espRenderTeam and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end
        return
    end
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local distance = (root.Position - localRoot.Position).Magnitude
    if distance > espRenderDistance then
        if data then data.Highlight.Enabled = false; data.Billboard.Enabled = false end
        return
    end
    CreateESP(player)
    data = espObjects[player]
    if not data then return end
    data.Highlight.Adornee = character
    data.Highlight.OutlineColor = espBoxColor
    data.Highlight.FillColor = espFillColor
    data.Highlight.OutlineTransparency = espBox and 0 or 1
    data.Highlight.FillTransparency = espBoxFill and espBoxFillTransparency or 1
    data.Highlight.Enabled = espBox or espBoxFill
    local lines = {}
    if espName then table.insert(lines, player.Name) end
    if espDistance then table.insert(lines, string.format("[%d studs]", math.floor(distance))) end
    if espHealthText then table.insert(lines, string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))) end
    if espTool then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then table.insert(lines, tool.Name) end
    end
    data.Text.Text = table.concat(lines, "\n")
    data.Text.TextColor3 = espNameColor
    data.Billboard.Adornee = root
    data.Billboard.Enabled = #lines > 0
end

local function UpdateAllESP()
    for _, player in ipairs(Players:GetPlayers()) do UpdatePlayerESP(player) end
end

local ESPPlayers = Tabs.ESP:AddLeftGroupbox("Players")
local ESPSettings = Tabs.ESP:AddRightGroupbox("Settings")
ESPPlayers:AddToggle("ESPEnabled", { Text = "Enabled", Default = false, Callback = function(v) espEnabled = v; if not v then UpdateAllESP() end end })
ESPPlayers:AddToggle("ESPBox", { Text = "Bounding Box", Default = false, Callback = function(v) espBox = v end }):AddColorPicker("ESPBoxColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Box Color", Callback = function(v) espBoxColor = v end })
ESPPlayers:AddToggle("ESPBoxFill", { Text = "Fill Box", Default = false, Callback = function(v) espBoxFill = v end }):AddColorPicker("ESPBoxFillColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Fill Color", Transparency = 0.5, Callback = function(v) espFillColor = v end })
ESPPlayers:AddSlider("ESPFillTransparency", { Text = "Fill Transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Callback = function(v) espBoxFillTransparency = v end })
ESPPlayers:AddToggle("ESPName", { Text = "Name", Default = false, Callback = function(v) espName = v end }):AddColorPicker("ESPNameColor", { Default = Color3.fromRGB(255, 255, 255), Title = "Name Color", Callback = function(v) espNameColor = v end })
ESPPlayers:AddToggle("ESPDistance", { Text = "Distance", Default = false, Callback = function(v) espDistance = v end })
ESPPlayers:AddToggle("ESPHealthText", { Text = "Health Text", Default = false, Callback = function(v) espHealthText = v end })
ESPPlayers:AddToggle("ESPTool", { Text = "Tool", Default = false, Callback = function(v) espTool = v end })
ESPSettings:AddSlider("ESPRenderHz", { Text = "Render Hertz", Min = 10, Max = 240, Default = 60, Rounding = 0, Callback = function(v) espRenderHz = v end })
ESPSettings:AddSlider("ESPRenderDistance", { Text = "Render Distance", Min = 10, Max = 1000, Default = 500, Rounding = 0, Callback = function(v) espRenderDistance = v end })
ESPSettings:AddToggle("ESPRenderTeam", { Text = "Render Teammates", Default = false, Callback = function(v) espRenderTeam = v end })

--========================================================--
-- VISUALS (FULL)
--========================================================--

local World = Tabs.Visuals:AddGroupbox({ Side = 1, Name = "World" })
local PlayerBoxV = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Player" })
local CameraBox = Tabs.Visuals:AddGroupbox({ Side = 2, Name = "Camera" })

local Ambient = AddToggle(World, "visuals/world/ambient", { Text = "Ambient", Default = false })
Ambient:AddColorPicker("visuals/world/ambient/outdoorcolor", { Default = Color3.fromRGB(200, 100, 60), Title = "Outdoor Color" })
Ambient:AddColorPicker("visuals/world/ambient/color", { Default = Color3.fromRGB(140, 90, 70), Title = "Ambient Color" })

local Brightness = AddToggle(World, "visuals/world/brightness", { Text = "Brightness", Default = false })
local BrightnessDep = World:AddDependencyBox()
BrightnessDep:AddSlider("visuals/world/brightness/level", { Text = "Brightness Level", Min = 0, Max = 10, Rounding = 1, Default = 1.6 })
BrightnessDep:AddSlider("visuals/world/brightness/envdiffscale", { Text = "Environment Diffuse Scale", Min = 0, Max = 1, Rounding = 2, Default = 1 })
BrightnessDep:AddSlider("visuals/world/brightness/envspecscale", { Text = "Environment Specular Scale", Min = 0, Max = 1, Rounding = 2, Default = 0.9 })
BrightnessDep:AddSlider("visuals/world/brightness/exposure", { Text = "Exposure Compensation", Min = 0, Max = 1, Rounding = 2, Default = 0.15 })
BrightnessDep:SetupDependencies({ { Toggles["visuals/world/brightness"], true } })

local Fog = AddToggle(World, "visuals/world/fog", { Text = "Fog", Default = false })
Fog:AddColorPicker("visuals/world/fog/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Fog Color" })
local FogDep = World:AddDependencyBox()
FogDep:AddSlider("visuals/world/fog/near", { Text = "Fog Near", Min = 0, Max = 1000, Rounding = 1, Default = 0 })
FogDep:AddSlider("visuals/world/fog/far", { Text = "Fog Far", Min = 0, Max = 1000, Rounding = 1, Default = 1000 })
FogDep:SetupDependencies({ { Toggles["visuals/world/fog"], true } })

local Shadow = AddToggle(World, "visuals/world/shadow", { Text = "Shadow Modification", Default = false })
Shadow:AddColorPicker("visuals/world/shadow/color", { Default = Color3.fromRGB(0, 0, 0), Title = "Shadow Color" })
local ShadowDep = World:AddDependencyBox()
ShadowDep:AddSlider("visuals/world/shadow/softness", { Text = "Shadow Softness", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
ShadowDep:AddToggle("visuals/world/shadow/globalshadows", { Text = "Enable Shadows", Default = true })
ShadowDep:SetupDependencies({ { Toggles["visuals/world/shadow"], true } })

local LightingT = AddToggle(World, "visuals/world/lighting", { Text = "Lighting", Default = false })
local LightingDep = World:AddDependencyBox()
LightingDep:AddSlider("visuals/world/lighting/time", { Text = "Clock Time", Min = 0, Max = 23, Rounding = 2, Default = 14 })
LightingDep:AddSlider("visuals/world/lighting/latitude", { Text = "Geographic Latitude", Min = -90, Max = 90, Rounding = 1, Default = 0 })
LightingDep:AddLabel("ColorShift Bottom"):AddColorPicker("visuals/world/lighting/colorshiftbottom", { Default = Color3.fromRGB(255, 255, 255), Title = "ColorShift Bottom" })
LightingDep:AddLabel("ColorShift Top"):AddColorPicker("visuals/world/lighting/colorshifttop", { Default = Color3.fromRGB(255, 255, 255), Title = "ColorShift Top" })
LightingDep:SetupDependencies({ { Toggles["visuals/world/lighting"], true } })

AddToggle(World, "visuals/world/lighting/colorgrading", { Text = "Color Grading", Default = false })
local ColorGradingDep = World:AddDependencyBox()
local TonemapOptions = {}
for _, EnumItem in Enum.TonemapperPreset:GetEnumItems() do
    table.insert(TonemapOptions, EnumItem.Name)
end
ColorGradingDep:AddDropdown("visuals/world/lighting/colorgrading/tonemap", { Text = "Tone Map Preset", Default = 1, Values = TonemapOptions })
ColorGradingDep:SetupDependencies({ { Toggles["visuals/world/lighting/colorgrading"], true } })

local CC = AddToggle(World, "visuals/world/lighting/cc", { Text = "Color Correction", Default = false })
local CCDep = World:AddDependencyBox()
CCDep:AddSlider("visuals/world/lighting/cc/saturation", { Text = "Saturation", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
CCDep:AddSlider("visuals/world/lighting/cc/contrast", { Text = "Contrast", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
CCDep:AddSlider("visuals/world/lighting/cc/brightness", { Text = "Brightness", Min = -1, Max = 1, Rounding = 2, Default = 0 })
CC:AddColorPicker("visuals/world/lighting/cc/tint", { Default = Color3.fromRGB(255, 255, 255), Title = "Tint Color" })
CCDep:SetupDependencies({ { Toggles["visuals/world/lighting/cc"], true } })

AddToggle(World, "visuals/world/lighting/bloom", { Text = "Bloom", Default = false })
local BloomDep = World:AddDependencyBox()
BloomDep:AddSlider("visuals/world/lighting/bloom/intensity", { Text = "Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
BloomDep:AddSlider("visuals/world/lighting/bloom/size", { Text = "Size", Min = 0, Max = 56, Rounding = 2, Default = 24 })
BloomDep:AddSlider("visuals/world/lighting/bloom/threshold", { Text = "Threshold", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
BloomDep:SetupDependencies({ { Toggles["visuals/world/lighting/bloom"], true } })

AddToggle(World, "visuals/world/sunrays", { Text = "Sun Rays", Default = false })
local SunRaysDep = World:AddDependencyBox()
SunRaysDep:AddSlider("visuals/world/sunrays/intensity", { Text = "Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.1 })
SunRaysDep:AddSlider("visuals/world/sunrays/spread", { Text = "Spread", Min = 0, Max = 1, Rounding = 2, Default = 0.5 })
SunRaysDep:SetupDependencies({ { Toggles["visuals/world/sunrays"], true } })

AddToggle(World, "visuals/world/atmosphere", { Text = "Atmosphere", Default = false })
local AtmosphereDep = World:AddDependencyBox()
AtmosphereDep:AddSlider("visuals/world/atmosphere/density", { Text = "Density", Min = 0, Max = 1, Rounding = 2, Default = 0.3 })
AtmosphereDep:AddSlider("visuals/world/atmosphere/offset", { Text = "Offset", Min = -1, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:AddLabel("Color"):AddColorPicker("visuals/world/atmosphere/color", { Default = Color3.fromRGB(199, 170, 107), Title = "Atmosphere Color" })
AtmosphereDep:AddLabel("Decay"):AddColorPicker("visuals/world/atmosphere/decay", { Default = Color3.fromRGB(106, 112, 125), Title = "Atmosphere Decay" })
AtmosphereDep:AddSlider("visuals/world/atmosphere/glare", { Text = "Glare", Min = 0, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:AddSlider("visuals/world/atmosphere/haze", { Text = "Haze", Min = 0, Max = 1, Rounding = 2, Default = 0 })
AtmosphereDep:SetupDependencies({ { Toggles["visuals/world/atmosphere"], true } })

AddToggle(World, "visuals/world/dof", { Text = "Depth of Field", Default = false })
local DOFDep = World:AddDependencyBox()
DOFDep:AddSlider("visuals/world/dof/farintens", { Text = "Far Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.28 })
DOFDep:AddSlider("visuals/world/dof/nearintens", { Text = "Near Intensity", Min = 0, Max = 1, Rounding = 2, Default = 0.7 })
DOFDep:AddSlider("visuals/world/dof/focusdist", { Text = "Focus Distance", Min = 0, Max = 100, Rounding = 2, Default = 20 })
DOFDep:AddSlider("visuals/world/dof/focusinradius", { Text = "In Focus Radius", Min = -100, Max = 100, Rounding = 2, Default = 20 })
DOFDep:SetupDependencies({ { Toggles["visuals/world/dof"], true } })

AddToggle(World, "visuals/world/weather", { Text = "Weather", Default = false })
local WeatherDep = World:AddDependencyBox()
WeatherDep:AddDropdown("visuals/world/weather/type", { Text = "Type", Default = 1, Values = {"Rain", "Snow"} })
WeatherDep:AddSlider("visuals/world/snow/rate", { Text = "Snow Rate", Min = 1, Max = 2000, Rounding = 0, Default = 1000 })
WeatherDep:SetupDependencies({ { Toggles["visuals/world/weather"], true } })

local SkyToggle = AddToggle(World, "visuals/world/customskybox", {
    Text = "Custom Sky Box", Default = false,
    Callback = function(v)
        skyboxEnabled = v
        if v then ApplySkybox(currentSkybox) else ApplySkybox("Default") end
    end
})
local SkyDep = World:AddDependencyBox()
SkyDep:AddDropdown("visuals/world/customskybox/type", {
    Text = "Type", Default = 1, Values = SkyNames,
    Callback = function(value)
        currentSkybox = value
        if skyboxEnabled then ApplySkybox(value) end
    end
})
SkyDep:SetupDependencies({ { Toggles["visuals/world/customskybox"], true } })

AddToggle(World, "visuals/world/use2022materials", {
    Text = "Use 2022 Materials", Default = false,
    Callback = function(v) pcall(function() sethiddenproperty(MaterialService, "Use2022Materials", v) end) end
})

local ChineseHat = AddToggle(PlayerBoxV, "visuals/player/chinesehat", { Text = "Chinese Hat", Default = false })
ChineseHat:AddColorPicker("visuals/player/chinesehat/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Chinese Hat Color" })
local ChineseHatDep = PlayerBoxV:AddDependencyBox()
ChineseHatDep:AddSlider("visuals/player/chinesehat/glowfac", { Text = "Glow Factor", Min = 10, Max = 20, Rounding = 0, Default = 10 })
ChineseHatDep:AddSlider("visuals/player/chinesehat/radius", { Text = "Radius", Min = 0, Max = 2, Rounding = 1, Default = 1.5 })
ChineseHatDep:AddSlider("visuals/player/chinesehat/height", { Text = "Height", Min = 0, Max = 2, Rounding = 1, Default = 1 })
ChineseHatDep:AddToggle("visuals/player/chinesehat/alwaysontop", { Text = "Always On Top", Default = false })
ChineseHatDep:SetupDependencies({ { Toggles["visuals/player/chinesehat"], true } })

AddToggle(PlayerBoxV, "visuals/player/appearance", { Text = "Appearance Changer", Default = false })
PlayerBoxV:AddInput("visuals/player/appearance/id", { Numeric = true, Finished = true, Text = "UserId" })

local Breadcrumbs = AddToggle(PlayerBoxV, "visuals/player/breadcrumbs", { Text = "Breadcrumbs", Default = false })
Breadcrumbs:AddColorPicker("visuals/player/breadcrumbs/color", { Default = Color3.fromRGB(255, 255, 255), Title = "Breadcrumbs Color" })
local BreadcrumbsDep = PlayerBoxV:AddDependencyBox()
BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/glowfac", { Text = "Glow Factor", Min = 10, Max = 20, Rounding = 0, Default = 10 })
BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/lifetime", { Text = "Life Time", Min = 0.1, Max = 5, Rounding = 1, Default = 5 })
BreadcrumbsDep:AddSlider("visuals/player/breadcrumbs/fadetime", { Text = "Fade Time", Min = 0.1, Max = 5, Rounding = 1, Default = 5 })
BreadcrumbsDep:SetupDependencies({ { Toggles["visuals/player/breadcrumbs"], true } })

AddToggle(CameraBox, "visuals/camera/waifu", { Text = "Waifu", Default = false })
local WaifuDep = CameraBox:AddDependencyBox()
WaifuDep:AddInput("visuals/camera/waifu/link", { Text = "Image / GIF URL", Default = "" })
WaifuDep:AddSlider("visuals/camera/waifu/x", { Text = "X", Min = -1920, Max = 1920, Rounding = 0, Default = 0 })
WaifuDep:AddSlider("visuals/camera/waifu/y", { Text = "Y", Min = -1080, Max = 1080, Rounding = 0, Default = 0 })
WaifuDep:AddSlider("visuals/camera/waifu/transparency", { Text = "Transparency", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })
WaifuDep:AddSlider("visuals/camera/waifu/scale", { Text = "Scale", Min = 0, Max = 1, Rounding = 1, Default = 0.5 })
WaifuDep:SetupDependencies({ { Toggles["visuals/camera/waifu"], true } })

--========================================================--
-- MISC (FULL)
--========================================================--

local Movement = Tabs.Misc:AddGroupbox({ Side = 1, Name = "Movement" })
local Exploits = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Exploits" })
local DesyncBox = Tabs.Misc:AddGroupbox({ Side = 2, Name = "Namsync" })

AddToggle(Movement, "misc/movement/speed", { Text = "Speed Hack", Default = false })
Movement:AddSlider("misc/movement/speed/value", { Text = "Speed Hack Value", Min = 1, Max = 500, Rounding = 0, Default = 30 })
Movement:AddDropdown("misc/movement/speed/method", { Text = "Speed Hack Method", Default = 1, Values = {"Directional", "MoveDir"} })

AddToggle(Movement, "misc/movement/moonwalk", { Text = "Moon Walk", Default = false }):AddKeyPicker("misc/movement/moonwalk/key", { Text = "Moon Walk Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

AddToggle(Movement, "misc/movement/autojump", { Text = "Auto Jump", Default = false })
Movement:AddDropdown("misc/movement/autojump/method", { Text = "Auto Jump Method", Default = 1, Values = {"Humanoid", "Velocity", "State"} })

AddToggle(Movement, "misc/movement/fly", { Text = "Fly", Default = false }):AddKeyPicker("misc/movement/fly/key", { Text = "Fly Key", SyncToggleState = false, Mode = "Hold", Default = "T" })
Movement:AddSlider("misc/movement/flyspeed/value", { Text = "Fly Speed", Min = 1, Max = 500, Rounding = 0, Default = 30 })

AddToggle(Movement, "misc/movement/noclip", { Text = "No Collisions", Default = false }):AddKeyPicker("misc/movement/noclip/key", { Text = "No Collisions Key", SyncToggleState = false, Mode = "Hold", Default = "T" })

AddToggle(Movement, "misc/movement/pixelsurf", { Text = "Pixel Surf", Default = false }):AddKeyPicker("misc/movement/pixelsurf/key", { Text = "Pixel Surf Key", SyncToggleState = false, Mode = "Hold", Default = "F" })

AddToggle(Exploits, "misc/exploits/antifling", { Text = "Anti Fling", Default = false })

AddToggle(DesyncBox, "misc/desync", { Text = "Enable", Default = false })
AddToggle(DesyncBox, "misc/desync/freezepos", { Text = "Freeze Position", Default = false }):AddKeyPicker("misc/desync/freezepos/key", { Text = "Freeze Pos Key", SyncToggleState = false, Mode = "Hold", Default = "E" })
AddToggle(DesyncBox, "misc/desync/randompos", { Text = "Random Position", Default = false }):AddKeyPicker("misc/desync/randompos/key", { Text = "Random Pos Key", SyncToggleState = false, Mode = "Toggle", Default = "F" })
local RandomPosDep = DesyncBox:AddDependencyBox()
RandomPosDep:AddSlider("misc/desync/randompos/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })
RandomPosDep:AddSlider("misc/desync/randompos/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })
RandomPosDep:AddSlider("misc/desync/randompos/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })
RandomPosDep:SetupDependencies({ { Toggles["misc/desync/randompos"], true } })

AddToggle(DesyncBox, "misc/desync/offset", { Text = "Offset", Default = false })
local OffsetDep = DesyncBox:AddDependencyBox()
OffsetDep:AddSlider("misc/desync/offset/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })
OffsetDep:AddSlider("misc/desync/offset/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })
OffsetDep:AddSlider("misc/desync/offset/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })
OffsetDep:AddSlider("misc/desync/offset/speed", { Text = "Animation Speed", Min = 0, Max = 100, Rounding = 1, Default = 10 })
OffsetDep:SetupDependencies({ { Toggles["misc/desync/offset"], true } })

AddToggle(DesyncBox, "misc/desync/jitter", { Text = "Jitter", Default = false })
local JitterDep = DesyncBox:AddDependencyBox()
JitterDep:AddSlider("misc/desync/jitter/x", { Text = "X", Min = -360, Max = 360, Rounding = 0, Default = 0 })
JitterDep:AddSlider("misc/desync/jitter/y", { Text = "Y", Min = -360, Max = 360, Rounding = 0, Default = 0 })
JitterDep:AddSlider("misc/desync/jitter/z", { Text = "Z", Min = -360, Max = 360, Rounding = 0, Default = 0 })
JitterDep:AddSlider("misc/desync/jitter/speed", { Text = "Speed", Min = 1, Max = 60, Rounding = 0, Default = 10 })
JitterDep:SetupDependencies({ { Toggles["misc/desync/jitter"], true } })

AddToggle(DesyncBox, "misc/desync/rotation", { Text = "Rotation Offset", Default = false })
local RotationDep = DesyncBox:AddDependencyBox()
RotationDep:AddSlider("misc/desync/rotation/x", { Text = "Pitch", Min = -180, Max = 180, Rounding = 0, Default = 0 })
RotationDep:AddSlider("misc/desync/rotation/y", { Text = "Yaw", Min = -180, Max = 180, Rounding = 0, Default = 0 })
RotationDep:AddSlider("misc/desync/rotation/z", { Text = "Roll", Min = -180, Max = 180, Rounding = 0, Default = 0 })
RotationDep:SetupDependencies({ { Toggles["misc/desync/rotation"], true } })

DesyncBox:AddSlider("misc/desync/speed", { Text = "Speed", Min = 0, Max = 100, Rounding = 1, Default = 1 })
AddToggle(DesyncBox, "misc/desync/useeasingstyle", { Text = "Use Easing Style", Default = false })
DesyncBox:AddDropdown("misc/desync/easingstyle", { Text = "Easing Style", Default = 1, Values = {"Sine", "Quad", "Cubic", "Quart", "Quint", "Exponential", "Circular", "Linear", "SmoothStep", "SmootherStep", "Back", "Elastic", "Bounce"} })
DesyncBox:AddDropdown("misc/desync/easingdirection", { Text = "Easing Direction", Default = 3, Values = {"In", "Out", "InOut"} })

--========================================================--
-- GAME MODS
--========================================================--

local GameInfo = Tabs.GameMods:AddLeftGroupbox("Game Info")
GameInfo:AddLabel("Place Name : " .. PlaceName)
GameInfo:AddLabel("Place ID : " .. tostring(PlaceId))

if IsBugFixes then
    GameInfo:AddLabel("Status : Supported")

    -- Teleports
    local SafeZones = Tabs.GameMods:AddLeftGroupbox("Safe Zones / POIs")
    for _, loc in ipairs(TeleportLocations) do
        SafeZones:AddButton(loc.Name, function()
            doTeleport(loc)
        end)
    end
    for _, loc in ipairs(HardcodedTPs) do
        SafeZones:AddButton(loc.Name, function()
            doTeleport(loc)
        end)
    end

    -- Item ESP
    local EspBox = Tabs.GameMods:AddLeftGroupbox("Item ESP")
    EspBox:AddToggle("ItemESP_Enabled", {
        Text = "Enabled", Default = false,
        Callback = function(v)
            itemEspEnabled = v
            if v then initialItemScan() else clearItemESP() end
        end
    })
    EspBox:AddToggle("ItemESP_Accessories", { Text = "Show Accessories", Default = true, Callback = function(v) showAccessories = v end })
    EspBox:AddToggle("ItemESP_Tools", { Text = "Show Tools", Default = true, Callback = function(v) showTools = v end })
    EspBox:AddToggle("ItemESP_WorkspaceOnly", { Text = "Workspace Only", Default = false, Callback = function(v) showWorkspaceOnly = v end })
    EspBox:AddToggle("ItemESP_OnPlayers", { Text = "Show On Players", Default = true, Callback = function(v) showOnPlayers = v end })
    EspBox:AddSlider("ItemESP_Distance", { Text = "Max Distance", Min = 50, Max = 2000, Default = 500, Rounding = 0, Callback = function(v) maxItemEspDistance = v end })

    -- Pray
    local PrayBox = Tabs.GameMods:AddRightGroupbox("Pray / Shrine")
    PrayBox:AddButton("Teleport to Shrine", function() doTeleport({ Name = "Shrine", Find = {"ShrineZone", "shrine"} }) end)
    PrayBox:AddButton("Fire GiveCrateItems (empty)", function() fireGiveCrateItems() end)
    PrayBox:AddButton("Fire GiveCrateItems (Player)", function() fireGiveCrateItems(LocalPlayer) end)
    PrayBox:AddButton("Fire GiveCrateItems (true)", function() fireGiveCrateItems(true) end)
    PrayBox:AddButton("Scan HonorEvents", function() scanHonorEvents() end)
    PrayBox:AddButton("Fire All HonorEvents", function() fireAllHonorRemotes() end)
    PrayBox:AddButton("Fire Player Tool Events", function() tryPlayerToolEvents() end)
    PrayBox:AddButton("FULL PRAY ATTEMPT", function() fullPrayAttempt() end)
else
    GameInfo:AddLabel("Status : Not Supported")
end

if ThemeManager and SaveManager then
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({"MenuKeybind"})
    ThemeManager:SetFolder("Testing")
    SaveManager:SetFolder("Testing")
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:ApplyToTab(Tabs.Settings)
end

--========================================================--
-- MAIN LOOP
--========================================================--

local function forceAmmo()
    local configurations = ReplicatedStorage:FindFirstChild("Configurations")
    if not configurations then return end
    local acsGuns = configurations:FindFirstChild("ACS_Guns")
    if not acsGuns then return end
    for _, folder in ipairs(acsGuns:GetChildren()) do
        local ammo = folder:FindFirstChild("Ammo")
        if ammo then pcall(function() ammo.Value = 999 end) end
    end
end

local function applyRainbowGun()
    if not rainbowGun and gunTransparency <= 0 then return end
    local char = LocalPlayer.Character
    if not char then return end
    if rainbowGun then gunHue = (gunHue + rainbowGunSpeed) % 1 end
    local gunColor = rainbowGun and Color3.fromHSV(gunHue, 1, 1) or nil
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        for _, obj in ipairs(tool:GetDescendants()) do
            if obj:IsA("BasePart") then
                if gunColor then
                    pcall(function() obj.Color = gunColor; obj.Material = Enum.Material.ForceField end)
                end
                pcall(function() obj.Transparency = gunTransparency end)
            end
        end
    end
end

local function UpdateChams()
    if not chamsEnabled then
        for _, hl in pairs(ChamObjects) do if hl then pcall(function() hl:Destroy() end) end end
        ChamObjects = {}
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local existing = ChamObjects[player]
            if not existing or not existing.Parent then
                local highlight = Instance.new("Highlight")
                highlight.Name = "ZexCham"
                highlight.Adornee = player.Character
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillColor = Color3.fromRGB(255, 255, 255)
                highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
                highlight.FillTransparency = 0.5
                highlight.Parent = CoreGui
                ChamObjects[player] = highlight
            else
                existing.Adornee = player.Character
            end
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        if Visuals and Visuals.Tick then Visuals.Tick(dt) end
        if Misc and Misc.Tick then Misc.Tick(dt) end
        if Desync and Desync.Tick then Desync.Tick(dt) end
    end)

    if espEnabled then
        espAccumulator = espAccumulator + dt
        if espAccumulator >= (1 / math.max(espRenderHz, 1)) then
            espAccumulator = 0
            UpdateAllESP()
        end
    end

    if itemEspEnabled then
        itemEspAccum = itemEspAccum + dt
        if itemEspAccum >= 1 then
            itemEspAccum = 0
            pcall(updateItemESP)
        end
    end

    local char = LocalPlayer.Character
    if not char then return end

    if cframeEnabled then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.MoveDirection.Magnitude > 0 then
            pcall(function() root.CFrame = root.CFrame + hum.MoveDirection * (cframeSpeed * 0.02) end)
        end
    end

    if lockFOV and Camera then
        pcall(function() Camera.FieldOfView = currentFOV end)
    end

    if rainbowBody then
        rainbowAccum = rainbowAccum + dt
        if rainbowAccum >= 0.05 then
            rainbowAccum = 0
            charHue = (charHue + rainbowBodySpeed * 3) % 1
            local bodyColor = Color3.fromHSV(charHue, 1, 1)
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                    pcall(function()
                        obj.Material = Enum.Material.ForceField
                        obj.Color = bodyColor
                        obj.Transparency = charTransparency
                    end)
                elseif obj:IsA("Accessory") then
                    local handle = obj:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        pcall(function()
                            handle.Material = Enum.Material.ForceField
                            handle.Color = bodyColor
                            handle.Transparency = charTransparency
                        end)
                    end
                end
            end
        end
    end

    applyRainbowGun()
    if infiniteAmmo then forceAmmo() end
    if chamsEnabled then UpdateChams() end
end)

Players.PlayerAdded:Connect(function(player)
    if espEnabled then CreateESP(player) end
end)
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    if ChamObjects[player] then
        pcall(function() ChamObjects[player]:Destroy() end)
        ChamObjects[player] = nil
    end
end)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then CreateESP(player) end
end

Library:OnUnload(function()
    if fallConnection then fallConnection:Disconnect() end
    if LimbExtender then pcall(function() LimbExtender:Stop() end) end
    ApplySkybox("Default")
    clearItemESP()
    for player in pairs(espObjects) do RemoveESP(player) end
    for _, hl in pairs(ChamObjects) do if hl then hl:Destroy() end end
    print("Moe unloaded")
end)

print("Teleports + Full Visuals/Misc + Skyboxes:", #SkyNames)
