import SwiftUI

// MARK: - 成员数据模型
struct Person: Identifiable, Hashable {
    let id: String
    let name: String
    let term: Int
    let role: String
    let tags: [String]
    let contribution: String
    let quote: String
    let grades: [String]?
    let archive: String?
    let photo: String?
    
    // 届数主题颜色 (适配 iOS 语义化配色)
    var termColor: Color {
        switch term {
        case 1: return Color(red: 0.58, green: 0.17, blue: 0.22)
        case 2: return Color(red: 0.67, green: 0.37, blue: 0.19)
        case 3: return Color(red: 0.61, green: 0.51, blue: 0.28)
        case 4: return Color(red: 0.26, green: 0.47, blue: 0.36)
        case 5: return Color(red: 0.27, green: 0.37, blue: 0.55)
        case 6: return Color(red: 0.40, green: 0.30, blue: 0.52)
        case 7: return Color(red: 0.54, green: 0.30, blue: 0.44)
        case 8: return Color(red: 0.22, green: 0.51, blue: 0.47)
        default: return .accentColor
        }
    }
}

// MARK: - 全量成员数据
struct HallOfFameData {
    static let termNames = ["一", "二", "三", "四", "五", "六", "七", "八"]
    
    static let people: [Person] = [
        // 第一届
        Person(id: "mayuzhang", name: "马雨璋", term: 1, role: "联合创始人 / 社长", tags: ["创社核心", "影视创作", "传媒中心", "《苏迷》"], contribution: "确立树莓社以影视创作为核心的社团定位，创立传媒中心。领导制作纪录片《苏迷》，带领社员参加48小时电影马拉松比赛。", quote: "相信影像的力量！\n技术会迭代，但影像传达的热情不会。只要电影梦还在，我们就有存在的价值。\n当你的声音流淌，世界屏息静听；当你的镜头开启，天地重赋色彩。", grades: ["A", "∞", "B", "A", "A", "C"], archive: "《数媒社创社策划案》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/mayuzhang.webp"),
        Person(id: "shensunfeng", name: "沈孙丰", term: 1, role: "联合创始人 / 社长 / 组委会主席", tags: ["组委会", "民主改革", "三项业务划分", "树莓文化"], contribution: "提出用\"树莓\"代替\"数字媒体\"，主导社团管理体制民主改革，起草《社团章程》。联合发起树莓派援助武汉抗疫募捐活动。", quote: "既然\"数字媒体\"听起来太专业、太遥远，那我们就用\"树莓\"来拉近影像与每个人的距离。\n我们要发现自己的特色，找到独属于树莓的生命力。\n制度的存在不是为了约束，而是为了让每一个创意都能在科学的轨道上精准落地。", grades: ["A", "B", "∞", "A", "A", "A"], archive: "《苏州中学树莓社章程》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/shensunfeng.webp"),
        Person(id: "zhangshihan", name: "张诗菡", term: 1, role: "联合创始人 / 副社长", tags: ["视觉设计", "树莓酱", "树莓文化"], contribution: "创造了树莓社看板娘形象并主导早期视觉体系，为树莓社社团文化的发展奠定基础。", quote: "虽然我们只是学生组织，我们的影响力绝不应被预设边界。树莓社将用行动证明，影像的力量可以深入到社会的各个领域之中，承担起远超预期的时代责任。", grades: ["B", "B", "A", "C", "A", "C"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhangshihan.webp"),
        
        // 第二届
        Person(id: "shiyunhan", name: "石允涵", term: 2, role: "第二任社长（双社长）", tags: ["双社长制", "照片直播"], contribution: "引入照片直播工作模式，开创摄影志愿服务品牌，大幅提高宣传时效性。荣获苏州市优秀社长称号。", quote: "\"面对挑战，我能行；遇到困难，我不怕；突发状况，我担当。\"\n“来树莓，种树莓，吃树莓，学数媒！”", grades: ["A", "A", "A", "A", "A", "A"], archive: "《树莓社摄影志愿服务团队开展情况报告》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/shiyunhan.webp"),
        Person(id: "liuenqi", name: "刘恩岐", term: 2, role: "第二任社长（双社长）", tags: ["经费保障", "后期部"], contribution: "树莓社历史双社长制代表。设计第二代工作证，为社团运营提供重要经费保障，起草《2019 年社长工作报告》。", quote: "", grades: ["C", "C", "B", "B", "A", "C"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/liuenqi.webp"),
        Person(id: "xingxiaohan", name: "邢笑菡", term: 2, role: "副社长 / 社盟副主席 / 代理社长", tags: ["代理社长", "部门优化"], contribution: "担任代理社长期间主持社团换届，提出部门结构优化方案。担任苏州中学社团联盟理事会副主席，促进跨社团交流。", quote: "", grades: ["B", "C", "B", "B", "A", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/xingxiaohan.webp"),
        Person(id: "yezhuo", name: "叶卓", term: 2, role: "代理社长 / 社盟主席", tags: ["B 站开创", "社联主席"], contribution: "开创树莓社 B 站官方账号，探索社团传播新矩阵。当选社团联盟理事会主席，将\"校级赋能\"升级为常态发展引擎。", quote: "", grades: ["B", "A", "B", "B", "C", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/yezhuo.webp"),
        
        // 第三届
        Person(id: "zhuyi", name: "朱奕", term: 3, role: "第三任社长", tags: ["走出困境", "《识茶记》"], contribution: "在面临内外挑战时带领社团走出困境，明确社团发展方向。推动《识茶记》等核心作品创作，举办\"破界\"创意摄影大赛。", quote: "", grades: ["B", "A", "A", "B", "B", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhuyi.webp"),
        Person(id: "luweiyi", name: "陆未一", term: 3, role: "策划与宣传部部长 / 第四届副社长", tags: ["公众号创始人", "视觉设计"], contribution: "创立\"苏中树莓社\"微信公众号并建立文案排版分工体系，设计 2021 版看板娘，开启了社团的全媒体传播时代。", quote: "", grades: ["B", "C", "B", "B", "C", "A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/luweiyi.webp"),
        Person(id: "guhengting", name: "顾衡庭", term: 3, role: "后期部部长 / 第四届副社长", tags: ["数字媒体技术"], contribution: "成功引入高画质实时视频直播工作流，并在 B 站运营及色彩管理技术规范中起到了决定性作用，确立了社团的技术壁垒。", quote: "", grades: ["B", "B", "B", "B", "B", "A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/guhengting.webp"),
        
        // 第四届
        Person(id: "wangyiyang", name: "汪翊扬", term: 4, role: "第四任社长 / 后期部部长", tags: ["创纪录招新"], contribution: "在\"网课学期\"克服疫情障碍坚持线上活动，带领第五届招新创下 79 人历史最高纪录。推动树莓社与多校社团结成树莓派联盟。", quote: "我们呈现生活，我们记录感动，用一帧帧画面还原真实。", grades: ["A", "B", "A", "A+", "B", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/wangyiyang.webp"),
        Person(id: "luziyi", name: "陆子易", term: 4, role: "副社长 / 后勤部部长 / 苏中社团联盟主席", tags: ["社团外联", "公共关系"], contribution: "第四届、第五届组委会核心成员。以社团联盟主席身份出席“树莓派·苏州数字媒体学生社团联盟”签约成立大会并见证签约。", quote: "", grades: ["A", "C", "A", "B", "A", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/luziyi.webp"),
        
        // 第五届
        Person(id: "liqian", name: "李谦", term: 5, role: "第五任社长 / 传媒中心负责人", tags: ["线下回归", "拍摄担当"], contribution: "以\"蒙故业，因遗策\"为治社纲领，采取过渡性战略，将受疫情影响的社团发展重心转移回线下，在各类大型活动中承担拍摄重任。", quote: "", grades: ["B", "C", "B", "B", "A", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/liqian.webp"),
        
        // 第六届
        Person(id: "zhouyijia", name: "周熠嘉", term: 6, role: "第六任社长 / 社盟成员", tags: ["数字化转型", "树莓派联盟"], contribution: "树莓派社团联盟主要创始人。推动社团治理数字化转型，提出\"回归社团本质、重视兴趣导向\"。创立《树莓日签》，推进 AIGC 研究。", quote: "现阶段的活动理念与社员实际期望的冲突，需要通过回归兴趣结社的社团本质来解决。", grades: ["A", "C", "A", "A", "A", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhouyijia.webp"),
        Person(id: "zhangyujiang", name: "张宇江", term: 6, role: "副社长 / 后期部部长", tags: ["后期部", "AIGC 探索"], contribution: "担任后期部负责人。在第六届社团管理中曾代行社长职权，为社团过渡期的稳定运作提供技术与管理保障。", quote: "", grades: ["B", "B", "C", "B", "A", "A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhangyujiang.webp"),
        Person(id: "wangyanran", name: "王嫣然", term: 6, role: "副社长 / 代理社长", tags: ["画纸共创", "创作者权益"], contribution: "开创树莓社 QQ 宣发阵地，主导\"共享相册\"活动。在社团联盟成立仪式上发表《保障创作者权益倡议》。执笔第六届年度工作报告。", quote: "当我们的感受跃然纸上，记忆便成为了作品。", grades: ["B", "A", "A", "B", "A", "∞"], archive: "树莓社 2024 年国旗下讲话", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/wangyanran.webp"),
        
        // 第七届
        Person(id: "yangziyan", name: "杨梓言", term: 7, role: "第七任社长", tags: ["全媒体矩阵", "伟大完成论"], contribution: "建成全媒体传播矩阵（累计传播超 20 万次）。面对 AI 冲击提出\"伟大完成论\"，强调\"从单纯技术传授升华为创意火种的传递\"。", quote: "让那些转瞬即逝的声音可以被听见，让每一个创意都拥有落地生长的土壤。", grades: ["A", "B", "B", "A", "A", "A"], archive: "《守温度、传火种、向未来》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/yangziyan.webp"),
        Person(id: "luoanqi", name: "雒安琪", term: 7, role: "传媒中心负责人", tags: ["问道山下广播", "抖音平台", "传媒中心", "树莓文化"], contribution: "运营《问道山下》广播节目。发起创建小红书账号，创立抖音账号，推动校园传媒业务创新与时代化改革。", quote: "无限进步，懂我们意思吧（划掉）", grades: ["B", "B", "A", "B", "C", "A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/luoanqi.webp"),
        Person(id: "zhujingxuan", name: "朱璟煊", term: 7, role: "策划与宣传部 / 第八届副社长", tags: ["树莓酱 IP", "品牌运营"], contribution: "主导\"树莓酱\"形象系统性迭代与 Q 版化开发，通过深耕周边文创，将社团文化成功转化为具象的视觉资产与文化符号。", quote: "", grades: ["C", "B", "A", "B", "C", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhujingxuan.webp"),
        
        // 第八届
        Person(id: "chenyuxin", name: "陈雨馨", term: 8, role: "第八任社长", tags: ["《寻找》主演", "第八代核心"], contribution: "原创微电影《寻找》主演。面对\"技术过剩而产出不足\"的问题提出尖锐反思，推动社团回归影像记录本质。", quote: "为什么我们树莓的技术已经足够成熟，产出却没能跟上呢？", grades: ["B", "A", "B", "B", "B", "B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/chenyuxin.webp")
    ]
}
