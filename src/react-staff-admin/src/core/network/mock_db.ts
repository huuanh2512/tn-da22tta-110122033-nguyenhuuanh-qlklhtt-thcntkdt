import { UserSession } from '../utils/auth_storage';

export interface MockSport {
  _id: string;
  id?: string;
  name: string;
  description: string;
  iconUrl?: string;
  teamSize: number;
  active: boolean;
}

export interface MockFacility {
  _id: string;
  name: string;
  city: string;
  fullAddress: string;
  active: boolean;
  staffIds: string[];
}

export interface MockCourt {
  _id: string;
  name: string;
  facilityId: string;
  sportId: string;
  code: string;
  status: 'ACTIVE' | 'MAINTENANCE';
  pricePerHour: number;
  openingMinutes: number; // e.g. 360 (6:00)
  closingMinutes: number; // e.g. 1320 (22:00)
  slotDurationMinutes: number; // e.g. 60
  slots: {
    slotIndex: number;
    startMinutes: number;
    endMinutes: number;
    isAvailable: boolean;
  }[];
}

export interface MockBooking {
  _id: string;
  courtId: string;
  userId: string;
  bookingDate: string; // yyyy-MM-dd
  startMinutes: number;
  endMinutes: number;
  totalPrice: number;
  status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED';
  createdAt: string;
}

export interface MockPayment {
  _id: string;
  bookingId: string;
  amount: number;
  method: 'CASH' | 'BANK_TRANSFER';
  transactionId: string;
  status: 'PENDING' | 'SUCCESS' | 'FAILED';
  createdAt: string;
}

// Initial Data
const INITIAL_SPORTS: MockSport[] = [
  { _id: 'sport_soccer', name: 'Bóng Đá', description: 'Sân cỏ nhân tạo chất lượng cao', teamSize: 7, active: true },
  { _id: 'sport_badminton', name: 'Cầu Lông', description: 'Thảm PVC chống trơn trượt', teamSize: 2, active: true },
  { _id: 'sport_tennis', name: 'Tennis', description: 'Sân tiêu chuẩn thi đấu', teamSize: 4, active: true }
];

const INITIAL_FACILITIES: MockFacility[] = [
  { _id: 'fac_q1', name: 'Sport Energy Quận 1', city: 'Hồ Chí Minh', fullAddress: '15 Lê Lợi, Bến Nghé, Quận 1', active: true, staffIds: ['user_staff_test'] },
  { _id: 'fac_q7', name: 'Sport Energy Quận 7', city: 'Hồ Chí Minh', fullAddress: '48 Nguyễn Thị Thập, Tân Hưng, Quận 7', active: true, staffIds: ['user_staff_test'] }
];

export const createDefaultSlots = (open: number, close: number, duration: number) => {
  const slots = [];
  let index = 1;
  for (let min = open; min + duration <= close; min += duration) {
    slots.push({
      slotIndex: index++,
      startMinutes: min,
      endMinutes: min + duration,
      isAvailable: true
    });
  }
  return slots;
};

const INITIAL_COURTS: MockCourt[] = [
  {
    _id: 'court_s1',
    name: 'Sân Bóng Đá 1',
    facilityId: 'fac_q1',
    sportId: 'sport_soccer',
    code: 'FB01',
    status: 'ACTIVE',
    pricePerHour: 300000,
    openingMinutes: 360, // 6h00
    closingMinutes: 1320, // 22h00
    slotDurationMinutes: 90, // 1h30
    slots: createDefaultSlots(360, 1320, 90)
  },
  {
    _id: 'court_s2',
    name: 'Sân Bóng Đá 2',
    facilityId: 'fac_q1',
    sportId: 'sport_soccer',
    code: 'FB02',
    status: 'ACTIVE',
    pricePerHour: 300000,
    openingMinutes: 360,
    closingMinutes: 1320,
    slotDurationMinutes: 90,
    slots: createDefaultSlots(360, 1320, 90)
  },
  {
    _id: 'court_b1',
    name: 'Sân Cầu Lông 1',
    facilityId: 'fac_q1',
    sportId: 'sport_badminton',
    code: 'BM01',
    status: 'ACTIVE',
    pricePerHour: 120000,
    openingMinutes: 480, // 8h00
    closingMinutes: 1200, // 20h00
    slotDurationMinutes: 60, // 1h00
    slots: createDefaultSlots(480, 1200, 60)
  },
  {
    _id: 'court_b2',
    name: 'Sân Cầu Lông 2',
    facilityId: 'fac_q1',
    sportId: 'sport_badminton',
    code: 'BM02',
    status: 'ACTIVE',
    pricePerHour: 120000,
    openingMinutes: 480,
    closingMinutes: 1200,
    slotDurationMinutes: 60,
    slots: createDefaultSlots(480, 1200, 60)
  },
  {
    _id: 'court_t1',
    name: 'Sân Tennis 1',
    facilityId: 'fac_q7',
    sportId: 'sport_tennis',
    code: 'TN01',
    status: 'ACTIVE',
    pricePerHour: 250000,
    openingMinutes: 360,
    closingMinutes: 1320,
    slotDurationMinutes: 120, // 2h00
    slots: createDefaultSlots(360, 1320, 120)
  }
];

const INITIAL_USERS: UserSession[] = [
  {
    _id: 'user_admin_sys',
    email: 'admin.system@gmail.com',
    role: 'ADMIN',
    status: 'ACTIVE',
    profile: { fullName: 'System Admin', phone: '0901234567', avatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=admin' }
  },
  {
    _id: 'user_staff_test',
    email: 'staff.test02@gmail.com',
    role: 'STAFF',
    status: 'ACTIVE',
    facilityId: 'fac_q1',
    profile: { fullName: 'Staff Test 02', phone: '0907654321', avatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=staff1' }
  },
  {
    _id: 'user_cust1',
    email: 'cust1@gmail.com',
    role: 'CUSTOMER',
    status: 'ACTIVE',
    profile: { fullName: 'Nguyễn Anh Tuấn', phone: '0933445566', avatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=cust1' }
  },
  {
    _id: 'user_cust2',
    email: 'cust2@gmail.com',
    role: 'CUSTOMER',
    status: 'ACTIVE',
    profile: { fullName: 'Phạm Minh Trí', phone: '0944556677', avatar: 'https://api.dicebear.com/7.x/adventurer/svg?seed=cust2' }
  }
];

// Helper to get formatted date string for today (yyyy-MM-dd)
const getTodayString = () => {
  const date = new Date();
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const INITIAL_BOOKINGS: MockBooking[] = [
  {
    _id: 'book_1',
    courtId: 'court_s1',
    userId: 'user_cust1',
    bookingDate: getTodayString(),
    startMinutes: 450, // 7:30
    endMinutes: 540, // 9:00
    totalPrice: 450000,
    status: 'CONFIRMED',
    createdAt: new Date().toISOString()
  },
  {
    _id: 'book_2',
    courtId: 'court_b1',
    userId: 'user_cust2',
    bookingDate: getTodayString(),
    startMinutes: 480, // 8:00
    endMinutes: 540, // 9:00
    totalPrice: 120000,
    status: 'PENDING',
    createdAt: new Date().toISOString()
  }
];

const INITIAL_PAYMENTS: MockPayment[] = [
  {
    _id: 'pay_1',
    bookingId: 'book_1',
    amount: 450000,
    method: 'BANK_TRANSFER',
    transactionId: 'TXN123456',
    status: 'SUCCESS',
    createdAt: new Date().toISOString()
  },
  {
    _id: 'pay_2',
    bookingId: 'book_2',
    amount: 120000,
    method: 'CASH',
    transactionId: '',
    status: 'PENDING',
    createdAt: new Date().toISOString()
  }
];

// Mock LocalStorage Database Handler
export const mockDB = {
  init: () => {
    const CURRENT_VERSION = 'v2';
    const savedVersion = localStorage.getItem('se_db_version');
    console.log('[DEBUG MOCK DB] init: savedVersion =', savedVersion, ', CURRENT_VERSION =', CURRENT_VERSION);
    
    if (savedVersion !== CURRENT_VERSION) {
      console.log('[DEBUG MOCK DB] Version mismatch. Clearing old mock data...');
      localStorage.removeItem('se_users');
      localStorage.removeItem('se_facilities');
      localStorage.removeItem('se_bookings');
      localStorage.removeItem('se_payments');
      localStorage.removeItem('se_courts');
      localStorage.removeItem('se_sports');
      localStorage.setItem('se_db_version', CURRENT_VERSION);
    }

    if (!localStorage.getItem('se_sports')) {
      localStorage.setItem('se_sports', JSON.stringify(INITIAL_SPORTS));
    }
    if (!localStorage.getItem('se_facilities')) {
      localStorage.setItem('se_facilities', JSON.stringify(INITIAL_FACILITIES));
    }
    if (!localStorage.getItem('se_courts')) {
      localStorage.setItem('se_courts', JSON.stringify(INITIAL_COURTS));
    }
    if (!localStorage.getItem('se_users')) {
      localStorage.setItem('se_users', JSON.stringify(INITIAL_USERS));
    }
    if (!localStorage.getItem('se_bookings')) {
      localStorage.setItem('se_bookings', JSON.stringify(INITIAL_BOOKINGS));
    }
    if (!localStorage.getItem('se_payments')) {
      localStorage.setItem('se_payments', JSON.stringify(INITIAL_PAYMENTS));
    }
  },

  getSports: (): MockSport[] => JSON.parse(localStorage.getItem('se_sports') || '[]'),
  saveSports: (data: MockSport[]) => localStorage.setItem('se_sports', JSON.stringify(data)),

  getFacilities: (): MockFacility[] => JSON.parse(localStorage.getItem('se_facilities') || '[]'),
  saveFacilities: (data: MockFacility[]) => localStorage.setItem('se_facilities', JSON.stringify(data)),

  getCourts: (): MockCourt[] => JSON.parse(localStorage.getItem('se_courts') || '[]'),
  saveCourts: (data: MockCourt[]) => localStorage.setItem('se_courts', JSON.stringify(data)),

  getUsers: (): UserSession[] => JSON.parse(localStorage.getItem('se_users') || '[]'),
  saveUsers: (data: UserSession[]) => localStorage.setItem('se_users', JSON.stringify(data)),

  getBookings: (): MockBooking[] => JSON.parse(localStorage.getItem('se_bookings') || '[]'),
  saveBookings: (data: MockBooking[]) => localStorage.setItem('se_bookings', JSON.stringify(data)),

  getPayments: (): MockPayment[] => JSON.parse(localStorage.getItem('se_payments') || '[]'),
  savePayments: (data: MockPayment[]) => localStorage.setItem('se_payments', JSON.stringify(data))
};

// Initialize DB immediately
mockDB.init();
