import axios from 'axios';
import { authStorage, UserSession } from '../utils/auth_storage';
import { mockDB, MockBooking, MockPayment, createDefaultSlots } from './mock_db';
import { firebaseAuth } from '../firebase/firebase_auth';
import { signOut } from 'firebase/auth';

const configuredApiUrl = process.env.REACT_APP_API_URL || 'https://doantotnghiep-f3bh.onrender.com/api/v1';
const API_BASE_URL =
  typeof window !== 'undefined' &&
  ['localhost', '127.0.0.1'].includes(window.location.hostname) &&
  configuredApiUrl.includes('10.0.2.2')
    ? configuredApiUrl.replace('10.0.2.2', 'localhost')
    : configuredApiUrl;
const USE_MOCK = false; // Set to false to use backend APIs

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request Interceptor: Attach JWT Token and Normalize Profile Data
apiClient.interceptors.request.use(
  (config) => {
    const token = authStorage.getAccessToken();
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    
    // Normalize outgoing profile fields
    if (config.data && typeof config.data === 'object') {
      const data = config.data;
      if (data.profile && typeof data.profile === 'object') {
        if (data.profile.fullName !== undefined && data.profile.name === undefined) {
          data.profile.name = data.profile.fullName;
        }
        if (data.profile.avatar !== undefined && data.profile.avatarUrl === undefined) {
          data.profile.avatarUrl = data.profile.avatar;
        }
      }
    }
    
    return config;
  },
  (error) => Promise.reject(error)
);

// Response Interceptor: Auto-Refresh Token on 401 and Data Normalization
apiClient.interceptors.response.use(
  (response) => {
    if (response && response.data) {
      const resData = response.data;
      
      // 1. Unwrap key 'data' if backend wraps payload
      if (resData.success && resData.data && typeof resData.data === 'object') {
        const payload = resData.data;
        if (payload.accessToken || payload.user || payload.items || payload.userId) {
          Object.assign(resData, payload);
        }
      }

      // Helper to normalize nested items (id, address, facility mappings)
      const normalizeItem = (item: any) => {
        if (!item || typeof item !== 'object') return;
        
        // Match both _id and id
        if (item.id && !item._id) item._id = item.id;
        if (item._id && !item.id) item.id = item._id;
        
        // Facility address flattening
        if (item.address && typeof item.address === 'object') {
          if (item.address.city && !item.city) item.city = item.address.city;
          if (item.address.full && !item.fullAddress) item.fullAddress = item.address.full;
        }
        
        // User/Court facility mapping
        if (item.facility && typeof item.facility === 'object') {
          const facIdVal = item.facility.id || item.facility._id;
          if (facIdVal && !item.facilityId) item.facilityId = facIdVal;
          if (item.facility.name && !item.facilityName) item.facilityName = item.facility.name;
        }

        // Court sport mapping
        if (item.sport && typeof item.sport === 'object') {
          const sportIdVal = item.sport.id || item.sport._id;
          if (sportIdVal && !item.sportId) item.sportId = sportIdVal;
          if (item.sport.name && !item.sportName) item.sportName = item.sport.name;
        }

        // Booking court mapping
        if (item.court && typeof item.court === 'object') {
          const courtIdVal = item.court.id || item.court._id;
          if (courtIdVal && !item.courtId) item.courtId = courtIdVal;
          if (item.court.name && !item.courtName) item.courtName = item.court.name;
        }

        // Booking/Payment user mapping
        if (item.user && typeof item.user === 'object') {
          const userIdVal = item.user.id || item.user._id;
          if (userIdVal && !item.userId) item.userId = userIdVal;
        }

        // Payment booking mapping
        if (item.booking && typeof item.booking === 'object') {
          const bookingIdVal = item.booking.id || item.booking._id;
          if (bookingIdVal && !item.bookingId) item.bookingId = bookingIdVal;
        }

        // User profile mapping
        if (item.profile && typeof item.profile === 'object') {
          if (item.profile.name && !item.profile.fullName) {
            item.profile.fullName = item.profile.name;
          }
          if (item.profile.fullName && !item.profile.name) {
            item.profile.name = item.profile.fullName;
          }
          if (item.profile.avatarUrl && !item.profile.avatar) {
            item.profile.avatar = item.profile.avatarUrl;
          }
          if (item.profile.avatar && !item.profile.avatarUrl) {
            item.profile.avatarUrl = item.profile.avatar;
          }
        }
        
        // Recursively normalize fields
        for (const key in item) {
          if (item[key] && typeof item[key] === 'object') {
            if (Array.isArray(item[key])) {
              item[key].forEach((subItem: any) => normalizeItem(subItem));
            } else {
              normalizeItem(item[key]);
            }
          }
        }
      };

      const normalizeApiResponse = (data: any) => {
        if (!data || typeof data !== 'object') return;
        if (Array.isArray(data.items)) {
          data.items.forEach((item: any) => normalizeItem(item));
        }
        if (data.facility) normalizeItem(data.facility);
        if (data.user) normalizeItem(data.user);
        if (data.court) normalizeItem(data.court);
        if (data.sport) normalizeItem(data.sport);
        if (data.booking) normalizeItem(data.booking);
        if (data.payment) normalizeItem(data.payment);
      };

      normalizeApiResponse(resData);
    }
    return response;
  },
  async (error) => {
    const originalRequest = error.config;
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        const firebaseUser = firebaseAuth.currentUser;
        if (!firebaseUser) throw new Error('No Firebase session');
        const response = await axios.post(`${API_BASE_URL}/auth/firebase/refresh`, {
          firebaseIdToken: await firebaseUser.getIdToken(true),
        });
        const { accessToken } = response.data;
        authStorage.setAccessToken(accessToken);
        
        // Retry the original request
        originalRequest.headers.Authorization = `Bearer ${accessToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        // The refresh request bypasses apiClient, so it cannot recurse. A rejected
        // Firebase refresh invalidates both identity and the local API session.
        await signOut(firebaseAuth).catch(() => undefined);
        authStorage.clear();
        window.location.href = '/sign-in';
        return Promise.reject(refreshError);
      }
    }
    return Promise.reject(error);
  }
);

// --- MOCK API INTERCEPTOR SYSTEM ---
// If USE_MOCK is true, intercept Axios requests and simulate responses from mockDB
if (USE_MOCK) {
  const createMockError = (status: number, data: any) => Object.assign(new Error(data?.message || 'Mock API error'), {
    response: { status, data }
  });

  apiClient.interceptors.request.use(async (config) => {
    const url = config.url || '';
    const method = (config.method || 'get').toLowerCase();
    
    // Parse data safely if it is a JSON string
    let parsedData = config.data;
    if (typeof parsedData === 'string') {
      try {
        parsedData = JSON.parse(parsedData);
      } catch (e) {
        parsedData = {};
      }
    }
    const data = parsedData || {};

    // Simulate network delay (300ms)
    await new Promise((resolve) => setTimeout(resolve, 300));

    // Router for Mock API endpoints
    try {
      // 1. Sign In
      if (url.includes('/auth/sign-in') && method === 'post') {
        const { email, password } = data;
        const users = mockDB.getUsers();
        console.log('[DEBUG MOCK API] Request sign-in data:', { email, password });
        console.log('[DEBUG MOCK API] Existing users in mockDB:', users);
        const user = users.find(u => u.email === email && u.status === 'ACTIVE');
        console.log('[DEBUG MOCK API] Found matching active user:', user);
        if (!user) {
          console.error('[DEBUG MOCK API] Sign-in failed. No active user matched with email:', email);
          throw createMockError(400, { success: false, message: 'Email hoặc mật khẩu không chính xác hoặc tài khoản bị khóa' });
        }
        // Simulated response
        const accessToken = `mock_access_token_${user._id}`;
        const refreshToken = `mock_refresh_token_${user._id}`;
        return Promise.reject({
          isMock: true,
          response: {
            status: 200,
            data: { success: true, accessToken, refreshToken, user }
          }
        });
      }

      // 2. Refresh Token
      if (url.includes('/auth/refresh-token') && method === 'post') {
        return Promise.reject({
          isMock: true,
          response: {
            status: 200,
            data: { success: true, accessToken: 'mock_new_access_token' }
          }
        });
      }

      // 3. Get User By ID or User List
      if (url.match(/\/user\/[a-zA-Z0-9_]+/) && method === 'get') {
        const userId = url.split('/').pop() || '';
        const users = mockDB.getUsers();
        const user = users.find(u => u._id === userId);
        if (!user) throw createMockError(404, { success: false, message: 'User not found' });
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, user } }
        });
      }

      if (url.includes('/user/') && method === 'get') {
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, users: mockDB.getUsers() } }
        });
      }

      // Modify role/assign facility/quick create
      if (url.match(/\/user\/[a-zA-Z0-9_]+\/role/) && method === 'put') {
        const userId = url.split('/')[3];
        const { role } = data;
        const users = mockDB.getUsers();
        const idx = users.findIndex(u => u._id === userId);
        if (idx !== -1) {
          users[idx].role = role;
          if (role !== 'STAFF') delete users[idx].facilityId;
          mockDB.saveUsers(users);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, user: users[idx] } }
        });
      }

      if (url.match(/\/user\/[a-zA-Z0-9_]+\/assign-facility/) && method === 'post') {
        const userId = url.split('/')[3];
        const { facilityId } = data;
        const users = mockDB.getUsers();
        const idx = users.findIndex(u => u._id === userId);
        if (idx !== -1) {
          users[idx].facilityId = facilityId;
          mockDB.saveUsers(users);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, user: users[idx] } }
        });
      }

      // Block User
      if (url.match(/\/user\/[a-zA-Z0-9_]+\/status/) && method === 'put') {
        const userId = url.split('/')[3];
        const { status } = data;
        const users = mockDB.getUsers();
        const idx = users.findIndex(u => u._id === userId);
        if (idx !== -1) {
          users[idx].status = status;
          mockDB.saveUsers(users);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, user: users[idx] } }
        });
      }

      // Quick register user
      if (url.includes('/auth/register') && method === 'post') {
        const { email, fullName, phone, role = 'CUSTOMER', facilityId } = data;
        const users = mockDB.getUsers();
        const exists = users.some(u => u.email === email);
        if (exists) throw createMockError(400, { success: false, message: 'Email đã tồn tại!' });

        const newId = `user_${Date.now()}`;
        const newUser: UserSession = {
          _id: newId,
          email,
          role,
          status: 'ACTIVE',
          facilityId,
          profile: {
            fullName,
            phone,
            avatar: `https://api.dicebear.com/7.x/adventurer/svg?seed=${newId}`
          }
        };
        users.push(newUser);
        mockDB.saveUsers(users);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, user: newUser } }
        });
      }

      // 4. Booking Slot Configuration
      if (url.match(/\/court\/[a-zA-Z0-9_]+\/slot-config/) && method === 'get') {
        const courtId = url.split('/')[3];
        const courts = mockDB.getCourts();
        const court = courts.find(c => c._id === courtId);
        if (!court) throw createMockError(404, { success: false });
        return Promise.reject({
          isMock: true,
          response: {
            status: 200,
            data: {
              success: true,
              openingMinutes: court.openingMinutes,
              closingMinutes: court.closingMinutes,
              slotDurationMinutes: court.slotDurationMinutes,
              slots: court.slots
            }
          }
        });
      }

      if (url.match(/\/court\/[a-zA-Z0-9_]+\/slot-config/) && method === 'put') {
        const courtId = url.split('/')[3];
        const { openingMinutes, closingMinutes, slotDurationMinutes, slots } = data;
        const courts = mockDB.getCourts();
        const idx = courts.findIndex(c => c._id === courtId);
        if (idx !== -1) {
          courts[idx].openingMinutes = openingMinutes;
          courts[idx].closingMinutes = closingMinutes;
          courts[idx].slotDurationMinutes = slotDurationMinutes;
          courts[idx].slots = slots;
          mockDB.saveCourts(courts);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true } }
        });
      }

      // 5. Booking Actions
      if (url.includes('/booking') && method === 'get') {
        const bookings = mockDB.getBookings();
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, bookings } }
        });
      }

      if (url.includes('/booking') && method === 'post') {
        const { courtId, bookingDate, startMinutes, endMinutes, totalPrice } = data;
        const bookings = mockDB.getBookings();
        // Check conflicts
        const conflicted = bookings.some(b => 
          b.courtId === courtId &&
          b.bookingDate === bookingDate &&
          b.status !== 'CANCELLED' &&
          !(endMinutes <= b.startMinutes || startMinutes >= b.endMinutes)
        );
        if (conflicted) throw createMockError(400, { success: false, message: 'Khung giờ này đã được đặt sân!' });

        // Deduce active user or walk-in (staff booked)
        const currentUser = authStorage.getUser();
        const userId = currentUser?.role === 'STAFF' ? 'user_cust1' : (currentUser?._id || 'user_guest');

        const newId = `book_${Date.now()}`;
        const newBooking: MockBooking = {
          _id: newId,
          courtId,
          userId,
          bookingDate,
          startMinutes,
          endMinutes,
          totalPrice,
          status: 'PENDING',
          createdAt: new Date().toISOString()
        };
        bookings.push(newBooking);
        mockDB.saveBookings(bookings);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, booking: newBooking } }
        });
      }

      if (url.match(/\/booking\/[a-zA-Z0-9_]+\/status/) && method === 'put') {
        const bookingId = url.split('/')[3];
        const { status } = data;
        const bookings = mockDB.getBookings();
        const idx = bookings.findIndex(b => b._id === bookingId);
        if (idx !== -1) {
          bookings[idx].status = status;
          mockDB.saveBookings(bookings);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true } }
        });
      }

      // 6. Payments
      if (url.includes('/payment') && method === 'get') {
        const payments = mockDB.getPayments();
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, payments } }
        });
      }

      if (url.includes('/payment') && method === 'post') {
        const { bookingId, amount, method: payMethod } = data;
        const payments = mockDB.getPayments();
        const newId = `pay_${Date.now()}`;
        const newPayment: MockPayment = {
          _id: newId,
          bookingId,
          amount,
          method: payMethod,
          transactionId: payMethod === 'BANK_TRANSFER' ? `TXN${Date.now()}` : '',
          status: 'PENDING',
          createdAt: new Date().toISOString()
        };
        payments.push(newPayment);
        mockDB.savePayments(payments);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, payment: newPayment } }
        });
      }

      if (url.match(/\/payment\/[a-zA-Z0-9_]+\/status/) && method === 'put') {
        const paymentId = url.split('/')[3];
        const { status, transactionId } = data;
        const payments = mockDB.getPayments();
        const idx = payments.findIndex(p => p._id === paymentId);
        if (idx !== -1) {
          payments[idx].status = status;
          if (transactionId) payments[idx].transactionId = transactionId;
          mockDB.savePayments(payments);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true } }
        });
      }

      // 7. Sport CRUD
      if (url.includes('/sport') && method === 'get') {
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, sports: mockDB.getSports() } }
        });
      }
      if (url.includes('/sport') && method === 'post') {
        const sports = mockDB.getSports();
        const newId = `sport_${Date.now()}`;
        const newSport = { _id: newId, ...data };
        sports.push(newSport);
        mockDB.saveSports(sports);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, sport: newSport } }
        });
      }
      if (url.match(/\/sport\/[a-zA-Z0-9_]+/) && method === 'put') {
        const sportId = url.split('/').pop() || '';
        const sports = mockDB.getSports();
        const idx = sports.findIndex(s => s._id === sportId);
        if (idx !== -1) {
          sports[idx] = { ...sports[idx], ...data };
          mockDB.saveSports(sports);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, sport: sports[idx] } }
        });
      }
      if (url.match(/\/sport\/[a-zA-Z0-9_]+/) && method === 'delete') {
        const sportId = url.split('/').pop() || '';
        let sports = mockDB.getSports();
        sports = sports.filter(s => s._id !== sportId);
        mockDB.saveSports(sports);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true } }
        });
      }

      // 8. Facility CRUD
      if (url.includes('/facility') && method === 'get') {
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, facilities: mockDB.getFacilities() } }
        });
      }
      if (url.includes('/facility') && method === 'post') {
        const facilities = mockDB.getFacilities();
        const newId = `fac_${Date.now()}`;
        const newFacility = { _id: newId, ...data };
        facilities.push(newFacility);
        mockDB.saveFacilities(facilities);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, facility: newFacility } }
        });
      }
      if (url.match(/\/facility\/[a-zA-Z0-9_]+/) && method === 'put') {
        const facilityId = url.split('/').pop() || '';
        const facilities = mockDB.getFacilities();
        const idx = facilities.findIndex(f => f._id === facilityId);
        if (idx !== -1) {
          facilities[idx] = { ...facilities[idx], ...data };
          mockDB.saveFacilities(facilities);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, facility: facilities[idx] } }
        });
      }
      if (url.match(/\/facility\/[a-zA-Z0-9_]+/) && method === 'delete') {
        const facilityId = url.split('/').pop() || '';
        let facilities = mockDB.getFacilities();
        facilities = facilities.filter(f => f._id !== facilityId);
        mockDB.saveFacilities(facilities);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true } }
        });
      }

      // 9. Court CRUD
      if (url.includes('/court') && method === 'get') {
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, courts: mockDB.getCourts() } }
        });
      }
      if (url.includes('/court') && method === 'post') {
        const courts = mockDB.getCourts();
        const newId = `court_${Date.now()}`;
        const newCourt = {
          _id: newId,
          ...data,
          openingMinutes: 360,
          closingMinutes: 1320,
          slotDurationMinutes: 60,
          slots: [] // will config slots later
        };
        // Auto create default slots
        newCourt.slots = createDefaultSlots(360, 1320, 60);
        courts.push(newCourt);
        mockDB.saveCourts(courts);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, court: newCourt } }
        });
      }
      if (url.match(/\/court\/[a-zA-Z0-9_]+/) && method === 'put') {
        const courtId = url.split('/').pop() || '';
        const courts = mockDB.getCourts();
        const idx = courts.findIndex(c => c._id === courtId);
        if (idx !== -1) {
          courts[idx] = { ...courts[idx], ...data };
          mockDB.saveCourts(courts);
        }
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true, court: courts[idx] } }
        });
      }
      if (url.match(/\/court\/[a-zA-Z0-9_]+/) && method === 'delete') {
        const courtId = url.split('/').pop() || '';
        let courts = mockDB.getCourts();
        courts = courts.filter(c => c._id !== courtId);
        mockDB.saveCourts(courts);
        return Promise.reject({
          isMock: true,
          response: { status: 200, data: { success: true } }
        });
      }

      // Fallback 404
      throw createMockError(404, { success: false, message: 'Mock API not found' });
    } catch (e: any) {
      if (e.isMock) return Promise.reject(e.response);
      return Promise.reject(e);
    }
  });

  // Catch the mock responses and resolve them
  apiClient.interceptors.response.use(
    (response) => response,
    (error) => {
      // 1. Check if the error is a mock response wrapper (isMock: true)
      if (error && error.isMock && error.response) {
        const mockRes = error.response;
        if (mockRes.status >= 200 && mockRes.status < 300) {
          return mockRes;
        }
        return Promise.reject(mockRes);
      }

      // 2. Check if it is a direct mock response that was thrown directly
      if (error && error.status) {
        if (error.status >= 200 && error.status < 300) {
          return error;
        }
        return Promise.reject(error);
      }
      return Promise.reject(error);
    }
  );
}
